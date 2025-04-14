import express from "express";
import { getUserContacts, searchUsers, addContact, updateFCMToken, getUserConversations, getMessages } from "../controllers/chat.controller.js";

const router = express.Router();

router.get("/chat/contacts", getUserContacts); // Get user contacts
router.get("/chat/search", searchUsers);
router.post("/chat/addContact", addContact);
router.post("/chat/updateFCMToken", updateFCMToken);
router.get("/chat/conversations", getUserConversations);
router.get("/chat/conversations/:conversationId/messages", getMessages);

export default router;
