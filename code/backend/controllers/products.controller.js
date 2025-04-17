import { Product } from "../models/models.js";
import { User } from "../models/models.js";
import mongoose from "mongoose";
import sharp from "sharp";
import dotenv from "dotenv";
dotenv.config();
export const createProduct = async (req, res) => {
    const { name, price, quantity, description, category, images, condition, available_from_date,seller_id } = req.body;

    if (!name || !price || !quantity || !description || !category || !condition || !seller_id) {
        return res.status(400).json({ success: false, message: "All fields are required" });
    }

    const validCategories = ['Farming', 'Pets', 'Cars', 'Tools', 'Furniture', 'Electronics'];
    const validConditions = ['New', 'Used - Like New', 'Used - Good', 'Used - Fair'];

    if (!validCategories.includes(category)) {
        return res.status(400).json({ success: false, message: "Invalid category" });
    }

    if (!validConditions.includes(condition)) {
        return res.status(400).json({ success: false, message: "Invalid condition" });
    }

    try {
        
        const seller = await User.findById(seller_id);
        const seller_name=seller.full_name;
        const pincode=seller.pincode

        if (!seller) {
            return res.status(404).json({ success: false, message: "Seller not found" });
        }
        let imageBuffers = [];

        if (images && Array.isArray(images)) {
            imageBuffers = await Promise.all(
                images.map(async (img) => {
                    const buffer = Buffer.from(img.data, 'base64');
                    const resized = await sharp(buffer)
                        .resize({ width: 800 }) 
                        .toFormat("jpeg")
                        .toBuffer();

                    return {
                        data: resized,
                        contentType: "image/jpeg"
                    };
                })
            );
        }
        const newProduct = new Product({
            name,
            price,
            quantity,
            description,
            seller_id,
            seller_name,
            pincode,
            category,
            images: imageBuffers,
            condition,
            available_from_date,
            is_flagged: false,
            flagged_count:  0,
            flagged_by: []
        });

        await newProduct.save();

        res.status(201).json({ success: true, message: "Product Created successfully", data: newProduct });
    } catch (error) {
        console.error("Error creating product:", error);
        res.status(500).json({ success: false, message: "Server Error" });
    }
};


export const allProductDetails = async (req, res) => {
    try {
        const products = await Product.find({}); 
        const formattedProducts = products.map((product) => {
            if (product.images && product.images.length > 0) {
                product.images = product.images.map((img) => {
                    if (img.data) {
                        return `data:image/jpeg;base64,${img.data.toString('base64')}`;
                    }
                    return null;
                });
            }
            return product;
        });

        res.status(200).json({
            success: true,
            message: "Products Details Fetched Successfully",
            data: formattedProducts,
        });
    } catch (error) {
        console.error("Error fetching products:", error);
        res.status(500).json({ message: "Internal Server Error" });
    }
};



export const ProductsofSeller = async (req, res) => {
    const { id } = req.params; 

    if (!mongoose.Types.ObjectId.isValid(id)) {
        return res.status(400).json({ success: false, message: "Invalid seller ID" });
    }

    try {
        const products = await Product.find({ seller_id: id });

        if (!products || products.length === 0) {
            return res.status(404).json({ success: false, message: "No products found for this seller" });
        }

        const formattedProducts = products.map((product) => {
            if (product.images && product.images.length > 0) {
                product.images = product.images.map((img) => {
                    if (img.data) {
                        return `data:image/jpeg;base64,${img.data.toString('base64')}`;
                    }
                    return null;
                });
            }
            return product;
        });

        res.status(200).json({
            success: true,
            message: "Products Fetched Successfully",
            data: formattedProducts,
        });
    } catch (error) {
        console.error("Error fetching products:", error);
        res.status(500).json({ success: false, message: "Internal Server Error" });
    }
};




export const updateProduct = async (req, res) => {
  const { id } = req.params;
  // Pull images out of the body, and everything else into “productData”
  const { images, ...productData } = req.body;

  if (!mongoose.Types.ObjectId.isValid(id)) {
    return res.status(404).json({ success: false, message: "Product Not Found" });
  }

  try {
    let imageBuffers = [];

    if (images && Array.isArray(images)) {
      // Resize + jpeg‐encode each one
      imageBuffers = await Promise.all(
        images.map(async ({ data }) => {
          const buffer = Buffer.from(data, 'base64');
          const resized = await sharp(buffer)
            .resize({ width: 800 })
            .jpeg()
            .toBuffer();

          return {
            data: resized,
            contentType: "image/jpeg",
          };
        })
      );
    }

    // Build the update payload: spread all other fields, and only include images if any
    const updatePayload = {
      ...productData,
      ...(imageBuffers.length > 0 && { images: imageBuffers }),
    };

    const updatedProduct = await Product.findByIdAndUpdate(
      id,
      updatePayload,
      { new: true, runValidators: true }
    );

    if (!updatedProduct) {
      return res.status(404).json({ success: false, message: "Product Not Found" });
    }

    res.status(200).json({ success: true, data: updatedProduct });
  } catch (error) {
    console.error("Error Updating Product:", error);
    res.status(500).json({ success: false, message: "Server Error" });
  }
};

export const deleteProduct = async (req, res) => {
    const { id } = req.params;
    if (!mongoose.Types.ObjectId.isValid(id)) {
        return res.status(400).json({ success: false, message: "Invalid product ID" });
    }
    try {
        const deletedProduct = await Product.findByIdAndDelete(id);
        if (!deletedProduct) {
            return res.status(404).json({ success: false, message: "Product not found" });
        }

        res.status(200).json({ success: true, message: "Product deleted successfully", data: deletedProduct });
    } catch (error) {
        console.error("Error deleting product:", error);
        res.status(500).json({ success: false, message: "Internal Server Error" });
    }
};
export const flagProduct = async (req, res) => {
    const { id } = req.params;
    const { userId } = req.body;

    if (!mongoose.Types.ObjectId.isValid(id)) {
        return res.status(400).json({ success: false, message: "Invalid product ID" });
    }

    try {
        const product = await Product.findById(id);
        if (!product) {
            return res.status(404).json({ success: false, message: "Product not found" });
        }

        if (product.flagged_by.includes(userId)) {
            return res.status(400).json({ success: false, message: "You already flagged this product" });
        }

        product.flagged_by.push(userId);
        product.flagged_count += 1;

        if (product.flagged_count >= 5) {
            product.is_flagged = true;
        }

        await product.save();

        res.status(200).json({ 
            success: true, 
            message: "Product flagged successfully",
            data: {
                flagged_count: product.flagged_count,
                is_flagged: product.is_flagged
            }
        });
    } catch (error) {
        console.error("Error flagging product:", error);
        res.status(500).json({ success: false, message: "Internal Server Error" });
    }
};
