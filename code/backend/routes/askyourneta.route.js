import express from "express";

import { sendmail } from "../controllers/askyourneta.controller.js";

const router = express.Router();
router.post("/askquery", sendmail)

export default router;