// --- Core Modules ---
import express from "express";
import http from "http";
import dotenv from "dotenv";
import mongoose from "mongoose";

// --- Middleware & Security ---
import cors from 'cors';
import helmet from 'helmet'; // Sets various security headers
import compression from 'compression'; // Compresses responses
import rateLimit from 'express-rate-limit'; // Basic rate limiting

// --- Real-time & Comms ---
import { Server } from "socket.io";
import jwt from 'jsonwebtoken'; // For Socket Auth
import admin from 'firebase-admin'; // For Push Notifications
import axios from 'axios'; // For calling Python service
import { readFile } from 'fs/promises'; // For reading JSON file

// --- Application Modules ---
import { connectDB } from "./config/db.js"; // Assuming DB connection logic is here
import userRoutes from "./routes/users.route.js"; // Assuming user API routes
import chatRoutes from "./routes/chat.route.js"; // Assuming chat API routes
import productRoutes from "./routes/products.route.js"; // Example other routes
import askyournetaRoutes from "./routes/askyourneta.route.js";
import newsRoutes from "./routes/news.route.js";
import { User, Conversation, Message } from "./models/models.js"; // Assuming Mongoose models

// --- Load Environment Variables ---
dotenv.config();

// --- Environment Variable Checks ---
const requiredEnvVars = [
    'PORT', 'MONGO_URI', 'JWT_SECRET',
    'FIREBASE_SERVICE_ACCOUNT_KEY_PATH'
];
const missingEnvVars = requiredEnvVars.filter(v => !process.env[v]);
if (missingEnvVars.length > 0) {
    console.error(`❌ FATAL ERROR: Missing required environment variables: ${missingEnvVars.join(', ')}`);
    process.exit(1);
}

// --- Firebase Admin SDK Initialization ---
try {
    const serviceAccountPath = new URL('./chatapp-35273-firebase-adminsdk-fbsvc-cc4efca1ca.json', import.meta.url);
    const serviceAccount = JSON.parse(await readFile(serviceAccountPath, 'utf8'));
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
    });
    console.log("✅ Firebase Admin SDK Initialized.");
} catch (error) {
    console.error("❌ Error initializing Firebase Admin SDK:", error.message);
    console.warn("⚠️ Push notifications will likely fail.");
    // Decide if this is fatal for your app: process.exit(1);
}

// --- Express App Setup ---
const app = express();
app.set('trust proxy', 1); // Trust first proxy if behind Nginx/Load Balancer for rate limiting IP

// --- Security Middleware ---
app.use(helmet()); // Set security-related HTTP headers
app.use(cors({
    origin: process.env.CORS_ORIGIN, // Restrict to specific origin in production
    methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    credentials: true // If you need cookies/sessions across domains
}));

// --- General Middleware ---
app.use(compression()); // Compress responses
app.use(express.json({ limit: '10mb' })); // Parse JSON bodies (adjust limit as needed)
app.use(express.urlencoded({ limit: '10mb', extended: true })); // Parse URL-encoded bodies
app.use(express.json());        // parse JSON bodies
app.use(express.urlencoded({ extended: true }));

// --- Basic API Rate Limiting ---
const apiLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // Limit each IP to 100 requests per windowMs
    message: 'Too many requests from this IP, please try again after 15 minutes',
    standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
    legacyHeaders: false, // Disable the `X-RateLimit-*` headers
});
app.use('/api/', apiLimiter); // Apply rate limiter to all API routes

// --- Application Logging Placeholder ---
app.use((req, res, next) => {
    console.log(`${new Date().toISOString()} - ${req.method} ${req.originalUrl}`);
    next();
});

// --- API Routes ---
app.use("/api/users", userRoutes);
app.use("/api/chat", chatRoutes); // Or maybe just /api/conversations ? Adjust prefix
app.use("/api/products", productRoutes);
app.use("/api/askyourneta", askyournetaRoutes);
app.use("/api/news", newsRoutes);
app.use('/api', userRoutes);    // mount user routes under /api

// --- Specific News Search Route (using Python Service) ---
const PYTHON_SERVICE_URL = process.env.PYTHON_SERVICE_URL || 'http://localhost:5001';
app.post('/api/news/search', apiLimiter, async (req, res, next) => { // Apply limiter here too
    try {
        const { query } = req.body;
        if (!query) {
            return res.status(400).json({ success: false, message: 'Query is required' });
        }
        console.log(`Searching for news: ${query}`);

        try {
            const response = await axios.post(`${PYTHON_SERVICE_URL}/search`, { query }, { timeout: 30000 });
            res.status(200).json(response.data); // Assume python service returns appropriate structure
        } catch (pythonError) {
            console.error('Error calling Python service:', pythonError.message);
            const status = pythonError.response?.status || 503; // Service Unavailable
            const message = pythonError.response?.data?.error || 'Python news service unavailable';
            const err = new Error(message);
            err.status = status;
            next(err); // Pass error to central handler
        }
    } catch (error) {
        next(error); // Pass unexpected errors to central handler
    }
});

// --- Health Check Endpoint ---
app.get('/health', (req, res) => {
    res.status(200).json({ status: 'UP' });
});

// --- HTTP Server Setup ---
const server = http.createServer(app);

// --- Socket.IO Server Setup (Default In-Memory Adapter) ---
const io = new Server(server, {
    cors: {
        origin: process.env.CORS_ORIGIN, // Use same origin as HTTP CORS
        methods: ["GET", "POST"]
    },
});
console.log("✅ Socket.IO initialized (using default in-memory adapter).");

// --- In-memory presence tracking (userId -> Set<socketId>) ---
const userSockets = new Map();

// --- Socket.IO Authentication Middleware ---
io.use((socket, next) => {
    const token = socket.handshake.auth?.token; // Use optional chaining
    if (!token) {
        console.warn(`Socket connection rejected: No token provided (Socket ID: ${socket.id})`);
        return next(new Error('Authentication error: No token provided'));
    }
    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        if (!decoded || !decoded.userId || !mongoose.Types.ObjectId.isValid(decoded.userId)) {
           throw new Error('Invalid token payload');
        }
        socket.userId = decoded.userId;
        next();
    } catch (err) {
        console.error(`Socket Authentication Error: ${err.message} (Socket ID: ${socket.id})`);
        return next(new Error('Authentication error: Invalid or expired token'));
    }
});

// --- Socket.IO Connection Logic ---
io.on('connection', (socket) => {
    const userId = socket.userId;
    console.log(`User connected: ${userId} (Socket ID: ${socket.id})`);

    if (!userSockets.has(userId)) {
        userSockets.set(userId, new Set());
    }
    userSockets.get(userId).add(socket.id);
    socket.join(userId);

    socket.on('disconnect', (reason) => {
        console.log(`User disconnected: ${userId} (Socket ID: ${socket.id}, Reason: ${reason})`);
        if (userSockets.has(userId)) {
            const userSocketSet = userSockets.get(userId);
            userSocketSet.delete(socket.id);
            if (userSocketSet.size === 0) {
                userSockets.delete(userId);
                console.log(`User ${userId} is now offline (removed from local map).`);
            }
        }
    });

    socket.on('sendMessage', async (data) => {
        if (!data || typeof data !== 'object') {
            return socket.emit('sendMessageError', { 
                tempId: data?.tempId, 
                error: 'Invalid data format.' 
            });
        }

        const { receiverId, text, type = 'text', mediaUrl = null, tempId = null } = data;
        const senderId = socket.userId;

        if (!receiverId || !mongoose.Types.ObjectId.isValid(receiverId)) {
            return socket.emit('sendMessageError', { 
                tempId, 
                error: 'Invalid receiver ID.' 
            });
        }

        if (type === 'text' && (!text || typeof text !== 'string' || text.trim().length === 0)) {
            return socket.emit('sendMessageError', { 
                tempId, 
                error: 'Text message cannot be empty.' 
            });
        }

        if (['image', 'video', 'file'].includes(type) && (!mediaUrl || typeof mediaUrl !== 'string')) {
            return socket.emit('sendMessageError', { 
                tempId, 
                error: 'Media URL required for this message type.' 
            });
        }

        if (senderId === receiverId) {
            return socket.emit('sendMessageError', { 
                tempId, 
                error: 'Cannot send messages to yourself.' 
            });
        }

        try {
            const participants = [senderId, receiverId].sort();
            let conversation = await Conversation.findOneAndUpdate(
                { participants: participants }, { updatedAt: new Date() }, { new: true, upsert: true }
            ).lean();

            const newMessage = new Message({
                conversationId: conversation._id, senderId, receiverId,
                text: type === 'text' ? text.trim() : null,
                mediaUrl: ['image', 'video', 'file'].includes(type) ? mediaUrl : null,
                type, timestamp: new Date(), status: 'sent'
            });
            await newMessage.save();

            Conversation.findByIdAndUpdate(conversation._id, { lastMessage: newMessage._id }).exec();

            const sender = await User.findById(senderId).select('full_name _id').lean();
            const messageToSend = {
                _id: newMessage._id,
                conversationId: newMessage.conversationId,
                senderId: newMessage.senderId,
                receiverId: newMessage.receiverId,
                text: newMessage.text,
                mediaUrl: newMessage.mediaUrl,
                type: newMessage.type,
                timestamp: newMessage.timestamp,
                status: newMessage.status,
                sender: sender ? { _id: sender._id, full_name: sender.full_name } : { _id: senderId },
            };

            const receiverSocketIds = userSockets.get(receiverId);
            if (receiverSocketIds && receiverSocketIds.size > 0) {
                io.to(receiverId).emit('receiveMessage', messageToSend);
                console.log(`Emitted message ${newMessage._id} to online user ${receiverId}`);
            } else {
                console.log(`User ${receiverId} offline. Sending push for message ${newMessage._id}.`);
                await sendPushNotification(
                    receiverId,
                    senderId,
                    newMessage.type === 'text' ? newMessage.text : `Sent you a ${newMessage.type}`,
                    conversation._id.toString()
                );
            }

            socket.emit('messageSent', { tempId: tempId, message: messageToSend });

        } catch (error) {
            console.error(`Error handling sendMessage from ${senderId} to ${receiverId}:`, error);
            socket.emit('sendMessageError', { 
                tempId, 
                error: 'Server failed to send message.' 
            });
        }
    });

    socket.on('typing', async (data) => {
        if (!data || typeof data !== 'object') return;
        const { conversationId, receiverId } = data;
        const senderId = socket.userId;
        if (!conversationId || !receiverId || !mongoose.Types.ObjectId.isValid(conversationId) || !mongoose.Types.ObjectId.isValid(receiverId)) return;

        try {
            const conversation = await Conversation.findOne({ _id: conversationId, participants: senderId }).select('_id').lean();
            if (!conversation) return;
            io.to(receiverId).emit('typing', { conversationId, senderId });
        } catch (error) { console.error(`Typing event error:`, error); }
    });

    socket.on('stopTyping', async (data) => {
        if (!data || typeof data !== 'object') return;
        const { conversationId, receiverId } = data;
        const senderId = socket.userId;
        if (!conversationId || !receiverId || !mongoose.Types.ObjectId.isValid(conversationId) || !mongoose.Types.ObjectId.isValid(receiverId)) return;

        try {
            const conversation = await Conversation.findOne({ _id: conversationId, participants: senderId }).select('_id').lean();
            if (!conversation) return;
            io.to(receiverId).emit('stopTyping', { conversationId, senderId });
        } catch (error) { console.error(`StopTyping event error:`, error); }
    });

    socket.on('markAsRead', async (data) => {
        if (!data || typeof data !== 'object') return;
        const { conversationId } = data;
        const readerId = socket.userId;
        if (!conversationId || !mongoose.Types.ObjectId.isValid(conversationId)) {
            return socket.emit('markAsReadError', { conversationId, error: "Invalid Conversation ID" });
        }

        try {
            const conversation = await Conversation.findOne({ _id: conversationId, participants: readerId }).select('participants').lean();
            if (!conversation) {
                return socket.emit('markAsReadError', { conversationId, error: "Conversation not found or access denied" });
            }
            const senderId = conversation.participants.find(pId => pId.toString() !== readerId);
            if (!senderId) {
                console.error(`Could not find sender for markAsRead: User ${readerId}, Convo: ${conversationId}`);
                return socket.emit('markAsReadError', { conversationId, error: "Could not identify message sender" });
            }

            const updateResult = await Message.updateMany(
                { conversationId: conversationId, receiverId: readerId, status: { $ne: 'read' } },
                { $set: { status: 'read' } }
            );

            if (updateResult.modifiedCount > 0) {
                io.to(senderId.toString()).emit('messagesRead', { conversationId, readerId });
            }
            socket.emit('markAsReadSuccess', { conversationId });

        } catch (error) {
            console.error(`Error handling markAsRead for user ${readerId}:`, error);
            socket.emit('markAsReadError', { conversationId, error: "Server error processing request" });
        }
    });

    socket.on('error', (err) => {
        console.error(`Socket error for user ${socket.userId}: ${err.message}`);
    });

});

// --- Push Notification Function ---
async function sendPushNotification(receiverId, senderId, messageText, conversationId) {
    if (!admin.apps.length) {
        console.warn("Firebase Admin not initialized. Cannot send push notification.");
        return;
    }
    try {
        const receiver = await User.findById(receiverId).select('fcmToken full_name allow_notifications').lean();
        const sender = await User.findById(senderId).select('full_name').lean();

        if (!receiver || !receiver.fcmToken || !receiver.allow_notifications) {
            console.log(`Cannot send notification to ${receiverId}: User not found, no token, or notifications disabled.`);
            return;
        }
        const senderName = sender ? sender.full_name : 'Someone';
        const notificationBody = messageText && messageText.length > 100 ? messageText.substring(0, 97) + '...' : messageText || `Sent you a message`;

        const messagePayload = {
            notification: { title: `New message from ${senderName}`, body: notificationBody },
            token: receiver.fcmToken,
            data: { type: 'newMessage', conversationId: conversationId.toString(), senderId: senderId.toString(), senderName },
            android: { priority: 'high', notification: { sound: 'default', channelId: 'new_messages_channel' } },
            apns: { payload: { aps: { sound: 'default', badge: 1, 'content-available': 1 } } }
        };

        const response = await admin.messaging().send(messagePayload);
        console.log(`Successfully sent FCM message to ${receiverId}:`, response);
    } catch (error) {
        console.error(`Error sending push notification to ${receiverId}:`, error);
        if (error.code === 'messaging/registration-token-not-registered') {
            User.findByIdAndUpdate(receiverId, { $unset: { fcmToken: "" } }).exec();
        }
    }
}

// --- 404 Not Found Handler ---
app.use((req, res, next) => {
    const error = new Error(`Not Found - ${req.originalUrl}`);
    error.status = 404;
    next(error);
});

// --- Central Error Handler ---
app.use((err, req, res, next) => {
    const statusCode = err.status || 500;
    console.error(`[${statusCode}] ${err.message} - ${req.originalUrl} - ${req.method} - ${req.ip}`);
    console.error(err.stack);

    const responseBody = {
        success: false,
        message: statusCode === 500 && process.env.NODE_ENV === 'production'
                 ? 'Internal Server Error'
                 : err.message,
    };

    res.status(statusCode).json(responseBody);
});

// --- Start Server ---
const PORT = process.env.PORT || 5000;

connectDB().then(() => {
    server.listen(PORT, () => {
        console.log(`✅ Database Connected`);
        console.log(`🚀 Server running on port ${PORT}`);
        console.log(`🔌 Socket.IO listening... (Default Adapter)`);
    });
}).catch(err => {
    console.error("❌ Failed to connect to MongoDB:", err);
    process.exit(1);
});

// --- Graceful Shutdown Handling ---
process.on('SIGTERM', () => {
    console.log('SIGTERM signal received: closing HTTP server');
    server.close(() => {
        console.log('HTTP server closed');
        mongoose.connection.close(false, () => {
            console.log('MongoDB connection closed');
            process.exit(0);
        });
    });
});

process.on('SIGINT', () => {
    console.log('SIGINT signal received: closing HTTP server');
    server.close(() => {
        console.log('HTTP server closed');
        mongoose.connection.close(false, () => {
            console.log('MongoDB connection closed');
            process.exit(0);
        });
    });
});