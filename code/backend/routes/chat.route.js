import express from "express";
import { getUserContacts, searchUsers, addContact, updateFCMToken, getUserConversations, getMessages, findOrCreateSellerConversation } from "../controllers/chat.controller.js";
import { authenticate } from "../middleware/authMiddleware.js"; // Assuming you have authentication middleware

const router = express.Router();

router.get("/chat/contacts", getUserContacts); // Get user contacts
router.get("/chat/search", searchUsers);
router.post("/chat/addContact", addContact);
router.post("/chat/updateFCMToken", updateFCMToken);
router.get("/chat/conversations", getUserConversations);
router.get("/chat/conversations/:conversationId/messages", getMessages);
router.post("/chat/product-seller/:productId/conversation", authenticate, findOrCreateSellerConversation); // New endpoint

export default router;
