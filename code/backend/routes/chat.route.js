import express from "express";
import { 
  getUserContacts, 
  searchUsers, 
  addContact, 
  updateFCMToken, 
  getUserConversations, 
  getMessages, 
  findOrCreateSellerConversation,
  sendMessage,
  createMessage // Add this import
} from "../controllers/chat.controller.js";
import { authenticate } from "../middleware/authMiddleware.js";

const router = express.Router();

// Remove the "/chat" prefix from all routes since they're mounted at "/api/chat"
router.get("/contacts", getUserContacts);
router.get("/search", searchUsers);
router.post("/addContact", addContact);
router.post("/updateFCMToken", updateFCMToken);
router.get("/conversations", authenticate, getUserConversations);
router.get("/conversations/:conversationId/messages", authenticate, getMessages);
router.post("/conversations/:conversationId/messages", authenticate, sendMessage);
router.post("/messages", authenticate, createMessage);
router.post("/product-seller/:productId/conversation", authenticate, findOrCreateSellerConversation);

export default router;
