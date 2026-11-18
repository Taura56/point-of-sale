const mongoose = require("mongoose");

const productSaleSchema = new mongoose.Schema(
  {
    business: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Business",
      required: true,
      index: true,
    },

    item: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "InventoryItem",
      required: true,
    },

    productName: {
      type: String,
      required: true,
      trim: true,
    },

    quantity: {
      type: Number,
      required: true,
      min: 1,
    },

    sellingPrice: {
      type: Number,
      required: true,
      min: 0,
    },

    profitPerUnit: {
      type: Number,
    },

    totalAmount: {
      type: Number,
      required: true,
      min: 0,
    },

    customerName: {
      type: String,
      trim: true,
      default: "Walk-in Customer",
    },

    customerPhone: {
      type: String,
      trim: true,
    },

    recordedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    paymentMethod: {
      type: String,
      enum: ["cash", "mpesa", "card", "other"],
      default: "cash",
    },

    paymentStatus: {
      type: String,
      enum: ["paid", "pending", "cancelled"],
      default: "paid",
    },

    notes: {
      type: String,
      trim: true,
    },
  },
  {
    timestamps: true,
    toJSON: {
      transform: (doc, ret) => {
        if (typeof ret.profitPerUnit === "number") {
          ret.profitAmount = ret.profitPerUnit * ret.quantity;
        }
        delete ret.profitPerUnit;
        return ret;
      },
    },
  }
);

productSaleSchema.index({ business: 1, createdAt: -1 });

module.exports = mongoose.model("ProductSale", productSaleSchema);
