import mongoose from "mongoose";


// --- Revised User Schema ---
const UserSchema = new mongoose.Schema({
    // --- Existing Fields (Keep As Is) ---
    full_name: String,
    phone_no: { type: String, unique: true, required: true },
    pincode: String,
    village_name: String,
    district: String,
    topic_of_interests: [String],
    is_premium: { type: Boolean, default: false },
    is_admin: { type: Boolean, default: false },
    is_blocked: { type: Boolean, default: false }, // Can be used to prevent blocked users from messaging
    referred_by: { type: mongoose.Schema.Types.ObjectId, ref: "User", default: null },
    allow_notifications: { type: Boolean, default: true }, // Default changed to true, assuming most users want notifications
    search_history: [String],

    // --- New/Chat-Related Fields ---
    contacts: [{ // List of user IDs this user has added as contacts
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User'
    }],
    fcmToken: { // Firebase Cloud Messaging Token for push notifications
        type: String,
        default: null, // Store the latest token here
        // Note: You might want to index this if you ever query *by* token, but usually you query by userId.
    },
    // Optional: lastSeen can be updated via WebSocket disconnect/connect events
    // lastSeen: { type: Date }

}, { timestamps: true }); // Add createdAt and updatedAt automatically


const ProductSchema = new mongoose.Schema({
    name: { type: String, required: true },
    price: { type: Number, required: true },
    quantity: { type: Number, required: true },
    description: String,
    seller_id: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
    seller_name: { type: String, required: true },
    category: {
        type: String,
        enum: ['Farming', 'Pets', 'Cars', 'Tools', 'Furniture', 'Electronics'],
        required: true
    },
    images: [{
        data: Buffer,
        contentType: String
    }],
    condition: {
        type: String,
        enum: ['New', 'Used - Like New', 'Used - Good', 'Used - Fair'],
        required: true
    },
    available_from_date: Date,
    is_flagged: { type: Boolean, default: false },
    flagged_count: { type: Number, default: 0 },
    flagged_by: [{ 
        type: mongoose.Schema.Types.ObjectId, 
        ref: "User" 
    }],
    pincode: String
});



const AskYourNetaSchema = new mongoose.Schema({
    user_id: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
    leader_id: { type: mongoose.Schema.Types.ObjectId, ref: "Leader", required: true },
    query: { type: String, required: true },
    reply: { type: String, default: null },
    constituency: String,
    created_at: { type: Date, default: Date.now }
});


const LeaderSchema = new mongoose.Schema({
    leader_name: { type: String, required: true },
    no_of_queries: { type: Number, default: 0 },
    no_of_replies: { type: Number, default: 0 },
    constituency: String
});


const NewsSchema = new mongoose.Schema({
    title: { type: String, required: true },
    content: String,
    category: String,
    source: String,
    source_link: String,
    timestamp: { type: Date, default: Date.now }
});


const ConversationSchema = new mongoose.Schema({
    participants: [{ // Array containing the ObjectIds of the two users in the conversation
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true
    }],
    lastMessage: { // Reference to the most recent message in this conversation
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Message',
        default: null
    },
    // createdAt and updatedAt are automatically added by timestamps: true
}, { timestamps: true }); // Enable automatic createdAt and updatedAt

// --- Indexes for Conversation Schema ---
// Index on participants for efficiently finding conversations involving specific users.
// Querying arrays needs careful consideration. Using $all operator is common.
// db.conversations.createIndex({ participants: 1 }) helps.
ConversationSchema.index({ participants: 1 });

// Index on updatedAt for efficiently sorting conversations by recent activity.
ConversationSchema.index({ updatedAt: -1 });


// --- Revised Message Schema ---
const MessageSchema = new mongoose.Schema({
    conversationId: { // Reference to the Conversation this message belongs to
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Conversation',
        required: true,
        index: true // Index for quickly fetching messages for a conversation
    },
    senderId: { // User who sent the message
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
        index: true // Index might be useful, e.g., "messages sent by user X"
    },
    receiverId: { // User who should receive the message (explicitly stored)
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
        index: true // Index might be useful, e.g., "messages received by user Y"
    },
    text: { // Renamed from message_text for convention
        type: String,
        required: function() { return this.type === 'text'; } // Only required if type is 'text'
    },
    mediaUrl: { // URL for image/video/file (assuming you upload elsewhere and store the URL)
        type: String,
        required: function() { return ['image', 'video', 'file'].includes(this.type); }
    },
    type: { // Renamed from message_type
        type: String,
        enum: ['text', 'image', 'video', 'file'], // Kept your types
        required: true
    },
    timestamp: { // Renamed from sent_at for convention, indexed for sorting messages
        type: Date,
        default: Date.now,
        index: true
    },
    status: { // To track if the message was sent, delivered, read
        type: String,
        enum: ['sent', 'delivered', 'read'],
        default: 'sent'
    },
    // Optional: Add fields if you implement message deletion/editing
    // isDeleted: { type: Boolean, default: false }
    // editedAt: { type: Date }

}, { timestamps: { createdAt: 'timestamp', updatedAt: false } }); // Use 'timestamp' field instead of mongoose's default createdAt

const MpSchema = new mongoose.Schema({
    mp_name: { type: String, required: true },
    mp_mail: { type: String, required: true },
    mp_constituency: { type: String, required: true },
});

export const User = mongoose.model("User", UserSchema);
export const Product = mongoose.model("Product", ProductSchema);
export const AskYourNeta = mongoose.model("AskYourNeta", AskYourNetaSchema);
export const Leader = mongoose.model("Leader", LeaderSchema);
export const News = mongoose.model("News", NewsSchema);
export const Conversation = mongoose.model("Conversation", ConversationSchema);
export const Message = mongoose.model("Message", MessageSchema);
export const MpModel = mongoose.model("mp", MpSchema, "mp_list");