// Assuming models are exported from '../models/chatModels.js' or similar
import { User, Conversation, Message, Product } from "../models/models.js"; // Adjust path if needed
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
const getUserContacts = async (req, res) => {
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
const searchUsers = async (req, res) => {
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
const addContact = async (req, res) => {
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
const updateFCMToken = async (req, res) => {
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
const getUserConversations = async (req, res) => {
    try {
        // Ensure req.user and req.user.id are defined
        if (!req.user || !req.user.id) {
            return res.status(401).json({ success: false, message: "Unauthorized: User not authenticated" });
        }

        const userId = req.user.id;
        console.log(`Fetching conversations for user: ${userId}`); // Debug log

        const conversations = await Conversation.find({ participants: userId }) // Find convos where user is a participant
            .populate({
                path: 'participants',
                match: { _id: { $ne: userId } }, // Ensure this does not exclude all participants
                select: 'full_name phone_no _id' // Select fields for the *other* participant(s)
                 // Add profile picture field if needed
            })
            .populate({
                path: 'lastMessage',
                select: 'text type timestamp senderId status' // Select fields for the last message preview
            })
            .sort({ updatedAt: -1 }); // Sort by the most recently updated conversation

        console.log(`Conversations fetched: ${JSON.stringify(conversations, null, 2)}`); // Debug log

        // Filter out conversations where the 'participants' array might be empty after the populate match
        // (This shouldn't happen in 1-on-1 chats if data integrity is maintained, but good practice)
        const validConversations = conversations.filter(convo => convo.participants.length > 0);
        console.log(`Valid conversations after filtering: ${validConversations.length}`); // Debug log

        res.status(200).json({ success: true, conversations: validConversations });

    } catch (error) {
        console.error("Error fetching conversations:", error); // Debug log
        handleError(res, error, "Error fetching conversations");
    }
};


/**
 * @description Get messages for a specific conversation with pagination
 * @route GET /api/conversations/:conversationId/messages?page=1&limit=20
 * @access Private (Requires Auth)
 */
const getMessages = async (req, res) => {
    const { conversationId } = req.params;

    // Ensure req.user is defined
    if (!req.user || !req.user.id) {
        console.error("Error: req.user is undefined or missing 'id'");
        return res.status(401).json({ success: false, message: "Unauthorized: User not authenticated" });
    }

    const userId = req.user.id;

    // Basic pagination setup
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;

    if (!mongoose.Types.ObjectId.isValid(conversationId)) {
        return res.status(400).json({ success: false, message: "Invalid Conversation ID" });
    }

    try {
        // Verify the user is part of this conversation
        const conversation = await Conversation.findOne({
            _id: conversationId,
            participants: userId,
        });

        if (!conversation) {
            return res.status(403).json({ success: false, message: "Access forbidden: You are not part of this conversation" });
        }

        // Fetch messages for the conversation with pagination
        const messages = await Message.find({ conversationId })
            .sort({ timestamp: -1 })
            .skip(skip)
            .limit(limit)
            .populate('senderId', 'full_name _id');

        res.status(200).json({ success: true, messages });
    } catch (error) {
        console.error("Error fetching messages:", error);
        res.status(500).json({ success: false, message: "Server Error" });
    }
};

/**
 * @description Find or create a conversation with a product seller
 * @route POST /api/chat/product-seller/:productId/conversation
 * @access Private (Requires Auth)
 */
const findOrCreateSellerConversation = async (req, res) => {
    const { productId } = req.params;
    const buyerId = req.user.id;

    if (!mongoose.Types.ObjectId.isValid(productId)) {
        return res.status(400).json({ success: false, message: "Invalid product ID" });
    }

    try {
        // 1. Find the product to get the seller ID
        const product = await Product.findById(productId).select('seller_id seller_name');
        
        if (!product) {
            return res.status(404).json({ success: false, message: "Product not found" });
        }

        const sellerId = product.seller_id;
        
        if (buyerId.toString() === sellerId.toString()) {
            return res.status(400).json({ success: false, message: "You cannot start a conversation with yourself" });
        }

        // 2. Find existing conversation or create a new one
        const participants = [buyerId, sellerId].sort();
        let conversation = await Conversation.findOne({ participants: { $all: participants, $size: 2 } })
            .populate({
                path: 'participants',
                match: { _id: { $ne: buyerId } }, // Get the other participant (seller)
                select: 'full_name _id'
            });

        if (!conversation) {
            // Create a new conversation
            conversation = new Conversation({ 
                participants: participants,
                updatedAt: new Date()
            });
            await conversation.save();
            
            // Re-fetch with populated fields
            conversation = await Conversation.findById(conversation._id)
                .populate({
                    path: 'participants',
                    match: { _id: { $ne: buyerId } },
                    select: 'full_name _id'
                });
        }

        // 3. Add the seller as a contact if they're not already
        await User.findByIdAndUpdate(
            buyerId, 
            { $addToSet: { contacts: sellerId } }, 
            { new: false }
        );

        // 4. Return the conversation data
        const sellerInfo = conversation.participants[0];
        
        res.status(200).json({
            success: true, 
            conversation: {
                _id: conversation._id,
                sellerId: sellerInfo._id,
                sellerName: sellerInfo.full_name || product.seller_name,
            }
        });
    } catch (error) {
        handleError(res, error, "Error finding/creating conversation with seller");
    }
};

/**
 * @description Send a new message in a conversation
 * @route POST /api/conversations/:conversationId/messages
 * @access Private (Requires Auth)
 */
const sendMessage = async (req, res) => {
    const { conversationId } = req.params;
    const { receiverId, text, type = 'text', mediaUrl } = req.body;
    const senderId = req.user.id;
    
    if (!mongoose.Types.ObjectId.isValid(conversationId)) {
        return res.status(400).json({ success: false, message: "Invalid Conversation ID" });
    }
    
    if (!receiverId || !text) {
        return res.status(400).json({ success: false, message: "Receiver ID and message text are required" });
    }

    try {
        // Verify the user is part of this conversation
        const conversation = await Conversation.findOne({
            _id: conversationId,
            participants: senderId,
        });

        if (!conversation) {
            return res.status(403).json({ success: false, message: "Access forbidden: You are not part of this conversation" });
        }
        
        // Create new message
        const newMessage = new Message({
            conversationId,
            senderId,
            receiverId,
            text,
            type,
            mediaUrl,
            timestamp: new Date(),
            status: 'sent' // Initial status
        });
        
        await newMessage.save();
        
        // Update the conversation's lastMessage and updatedAt
        await Conversation.findByIdAndUpdate(conversationId, {
            lastMessage: newMessage._id,
            updatedAt: new Date()
        });
        
        // Populate the sender details in the response
        const populatedMessage = await Message.findById(newMessage._id)
            .populate('senderId', 'full_name _id');
        
        res.status(201).json({ 
            success: true, 
            message: populatedMessage 
        });
        
    } catch (error) {
        handleError(res, error, "Error sending message");
    }
};

export {
    getUserContacts,
    searchUsers,
    addContact,
    updateFCMToken,
    getUserConversations,
    getMessages,
    findOrCreateSellerConversation,
    sendMessage // Export the new function
};