// Assuming models are exported from '../models/chatModels.js' or similar
import { User, Conversation, Message } from "../models/models.js"; // Adjust path if needed
import mongoose from "mongoose";

// --- Helper Function for Error Responses ---
const handleError = (res, error, message = "Server Error", statusCode = 500) => {
    console.error(message, error);
    res.status(statusCode).json({ success: false, message });
};

// --- User Related Endpoints ---

/**
 * @description Get the contact list for the logged-in user
 * @route GET /api/users/contacts
 * @access Private (Requires Auth)
 */
export const getUserContacts = async (req, res) => {
    try {
        const userId = req.user.id; // Assuming auth middleware provides this

        const user = await User.findById(userId)
            .select('contacts') // Only select the contacts field
            .populate({
                path: 'contacts',
                select: 'full_name phone_no _id' // Select fields you want to show for contacts
                // Add profile picture URL field here if you add it to the User model
            });

        if (!user) {
            return res.status(404).json({ success: false, message: "User not found" });
        }

        res.status(200).json({ success: true, contacts: user.contacts || [] });

    } catch (error) {
        handleError(res, error, "Error fetching contacts");
    }
};

/**
 * @description Search for users to add as contacts
 * @route GET /api/users/search?query=...
 * @access Private (Requires Auth)
 */
export const searchUsers = async (req, res) => {
    const query = req.query.query ? String(req.query.query).trim() : '';
    const userId = req.user.id;

    if (!query) {
        return res.status(400).json({ success: false, message: "Search query is required" });
    }

    try {
        // Search by full_name (case-insensitive) or phone_no
        // Exclude the current user from search results
        // Limit results for performance
        const users = await User.find({
            _id: { $ne: userId }, // Don't find self
            is_blocked: { $ne: true }, // Optional: Don't find blocked users
            $or: [
                { full_name: { $regex: query, $options: 'i' } }, // Case-insensitive regex search
                { phone_no: { $regex: query, $options: 'i' } } // Or search by phone number
            ]
        })
        .select('full_name phone_no _id') // Select fields to return
        .limit(10); // Limit the number of results

        res.status(200).json({ success: true, users });

    } catch (error) {
        handleError(res, error, "Error searching users");
    }
};

/**
 * @description Add a user to the logged-in user's contact list
 * @route POST /api/users/addContact
 * @access Private (Requires Auth)
 */
export const addContact = async (req, res) => {
    const { contactId } = req.body;
    const userId = req.user.id;

    if (!contactId || !mongoose.Types.ObjectId.isValid(contactId)) {
        return res.status(400).json({ success: false, message: "Valid Contact ID is required" });
    }

    if (userId === contactId) {
         return res.status(400).json({ success: false, message: "You cannot add yourself as a contact" });
    }

    try {
        // 1. Check if the contact user exists
        const contactExists = await User.findById(contactId);
        if (!contactExists) {
            return res.status(404).json({ success: false, message: "User to add not found" });
        }

        // 2. Add the contactId to the current user's contacts array using $addToSet to prevent duplicates
        const updatedUser = await User.findByIdAndUpdate(
            userId,
            { $addToSet: { contacts: contactId } }, // $addToSet prevents duplicates
            { new: true } // Return the updated document
        );

        if (!updatedUser) {
            return res.status(404).json({ success: false, message: "Current user not found" });
        }

        // Maybe you want to add the current user to the *other* person's contacts too?
        // If so, uncomment the following:
        // await User.findByIdAndUpdate(contactId, { $addToSet: { contacts: userId } });

        res.status(200).json({ success: true, message: "Contact added successfully" });

    } catch (error) {
        handleError(res, error, "Error adding contact");
    }
};


/**
 * @description Update the FCM token for the logged-in user
 * @route PUT /api/users/me/updateFCMToken
 * @access Private (Requires Auth)
 */
export const updateFCMToken = async (req, res) => {
    const { fcmToken } = req.body;
    const userId = req.user.id;

    if (!fcmToken) {
        return res.status(400).json({ success: false, message: "FCM token is required" });
    }

    try {
        const user = await User.findByIdAndUpdate(
            userId,
            { $set: { fcmToken: fcmToken } }, // Use $set to update the field
            { new: true } // Optionally return the updated document
        );

        if (!user) {
            return res.status(404).json({ success: false, message: "User not found" });
        }

        res.status(200).json({ success: true, message: "FCM token updated successfully" });

    } catch (error) {
        handleError(res, error, "Error updating FCM token");
    }
};


// --- Conversation & Message Related Endpoints ---

/**
 * @description Get all conversations for the logged-in user, sorted by recent activity
 * @route GET /api/conversations
 * @access Private (Requires Auth)
 */
export const getUserConversations = async (req, res) => {
    try {
        const userId = req.user.id;

        const conversations = await Conversation.find({ participants: userId }) // Find convos where user is a participant
            .populate({
                path: 'participants',
                match: { _id: { $ne: userId } }, // Exclude the current user from populated participants
                select: 'full_name phone_no _id' // Select fields for the *other* participant(s)
                 // Add profile picture field if needed
            })
            .populate({
                path: 'lastMessage',
                select: 'text type timestamp senderId status' // Select fields for the last message preview
            })
            .sort({ updatedAt: -1 }); // Sort by the most recently updated conversation

        // Filter out conversations where the 'participants' array might be empty after the populate match
        // (This shouldn't happen in 1-on-1 chats if data integrity is maintained, but good practice)
        const validConversations = conversations.filter(convo => convo.participants.length > 0);

        res.status(200).json({ success: true, conversations: validConversations });

    } catch (error) {
        handleError(res, error, "Error fetching conversations");
    }
};


/**
 * @description Get messages for a specific conversation with pagination
 * @route GET /api/conversations/:conversationId/messages?page=1&limit=20
 * @access Private (Requires Auth)
 */
export const getMessages = async (req, res) => {
    const { conversationId } = req.params;
    const userId = req.user.id;

    // Basic pagination setup
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20; // Default limit 20 messages
    const skip = (page - 1) * limit;

    if (!mongoose.Types.ObjectId.isValid(conversationId)) {
        return res.status(400).json({ success: false, message: "Invalid Conversation ID" });
    }

    try {
        // 1. Verify the user is part of this conversation (Security Check)
        const conversation = await Conversation.findOne({
            _id: conversationId,
            participants: userId // Check if logged-in user is in the participants array
        });

        if (!conversation) {
            return res.status(403).json({ success: false, message: "Access forbidden: You are not part of this conversation" });
        }

        // 2. Fetch messages for the conversation with pagination
        const messages = await Message.find({ conversationId: conversationId })
            .sort({ timestamp: -1 }) // Sort by timestamp descending (newest first)
            .skip(skip)
            .limit(limit)
            .populate('senderId', 'full_name _id'); // Optionally populate sender info

        // You might want to return the total count for pagination calculation on the frontend
        const totalMessages = await Message.countDocuments({ conversationId: conversationId });

        res.status(200).json({
            success: true,
            messages: messages.reverse(), // Reverse for typical chat UI order (oldest at top)
            currentPage: page,
            totalPages: Math.ceil(totalMessages / limit),
            totalMessages: totalMessages
        });

    } catch (error) {
        handleError(res, error, "Error fetching messages");
    }
};

export {
    getUserContacts,
    searchUsers,
    addContact,
    updateFCMToken,
    getUserConversations,
    getMessages
};