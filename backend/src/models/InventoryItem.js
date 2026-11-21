const mongoose = require("mongoose");

const inventoryItemSchema = new mongoose.Schema(
  {
    business: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Business",
      required: true,
      index: true,
    },

    name: {
      type: String,
      required: true,
      trim: true,
    },

    category: {
      type: String,
      enum: [
        "phone_accessory",
        "phone_part",
        "electronics",
        "mens_clothing",
        "womens_clothing",
        "unisex_clothing",
        "mens_shoes",
        "womens_shoes",
        "other",
      ],
      default: "other",
    },

    gender: {
      type: String,
      enum: ["mens", "womens", "unisex", "other"],
    },

    productType: {
      type: String,
      enum: [
        "trousers",
        "shirts",
        "t_shirts",
        "dresses",
        "tops",
        "skirts",
        "jackets",
        "sweaters",
        "shoes",
        "other",
      ],
    },

    size: {
      type: String,
      trim: true,
    },

    color: {
      type: String,
      trim: true,
    },

    condition: {
      type: String,
      trim: true,
    },

    sku: {
      type: String,
      trim: true,
    },

    costPrice: {
      type: Number,
      required: true,
      min: 0,
    },

    sellingPrice: {
      type: Number,
      required: true,
      min: 0,
    },

    quantityInStock: {
      type: Number,
      required: true,
      min: 0,
      default: 0,
    },

    reservedQuantity: {
      type: Number,
      required: true,
      min: 0,
      default: 0,
    },

    reorderLevel: {
      type: Number,
      min: 0,
      default: 5,
    },

    isActive: {
      type: Boolean,
      default: true,
    },

    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
  },
  {
    timestamps: true,
  }
);

inventoryItemSchema.index({ business: 1, createdAt: -1 });

module.exports = mongoose.model(
  "InventoryItem",
  inventoryItemSchema
);