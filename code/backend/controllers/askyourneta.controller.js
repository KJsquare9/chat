import { MpModel } from "../models/models.js";
import nodemailer from "nodemailer";
import dotenv from "dotenv";
dotenv.config();

export const sendmail = async (req, res) => {
  try {

    const { name, constituency, question} = req.body;
    console.log(name, constituency, question);
    if (!name || !constituency || !question) {
      return res.status(400).json({ error: "Missing name, constituency, or question" });
    }

    // Step 1: Fetch MP details
    const mp = await MpModel.findOne({
      mp_name: name,
      mp_constituency: constituency,
    });

    if (!mp) {
      console.log("heedcd");
      return res.status(404).json({ error: "MP not found" });
    }

    const receiver = mp.mp_mail; // Get MP's email from DB

    // Step 2: Configure nodemailer
    var transporter = nodemailer.createTransport({
      service: "gmail",
      auth: {
        user: process.env.USER_MAIL,
        pass: process.env.APP_PASSWORD,
      },
    });

    var mailOptions = {
      from: process.env.user_mail,
      to: receiver,
      subject: "Question from a citizen",
      text: typeof question === "string" ? question : JSON.stringify(question),
    };

    // Step 3: Send email
    transporter.sendMail(mailOptions, (error, info) => {
      if (error) {
        console.error("Error sending email:", error);
        return res.status(500).json({ error: "Failed to send email" });
      }
      console.log("Email sent:", info.response);
      res.status(200).json({ message: "Email sent successfully" });
    });
  } catch (err) {
    console.error("Unexpected error:", err);
    res.status(500).json({ error: "Server error" });
  }
};