import express from "express";
import { authenticate } from "../middleware/authMiddleware.js";
import { 
    createProduct,
    allProductDetails,
    ProductsofSeller,
    updateProduct,
    deleteProduct,
    flagProduct 
} from "../controllers/products.controller.js";

const router=express.Router();
router.post("/", authenticate, createProduct);
router.get("/", allProductDetails);
router.get("/:id",ProductsofSeller);
router.put("/:id", authenticate, updateProduct);
router.delete("/:id", authenticate, deleteProduct);
router.post("/:id/flag", authenticate, flagProduct);

export default router;