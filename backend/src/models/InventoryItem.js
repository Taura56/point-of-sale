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
        "other",
      ],
      default: "other",
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