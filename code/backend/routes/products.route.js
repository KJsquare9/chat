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
router.post("/products", authenticate, createProduct);
router.get("/products", allProductDetails);
router.get("/products/:id",ProductsofSeller);
router.put("/products/:id", authenticate, updateProduct);
router.delete("/products/:id", authenticate, deleteProduct);
router.post("/products/:id/flag", authenticate, flagProduct);

export default router;