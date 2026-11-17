const mongoose = require("mongoose");

const transactionSchema = new mongoose.Schema(
  {
    // Business that owns this transaction
    business: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Business",
      required: true,
      index: true,
    },

    // Service being provided
    service: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Service",
      required: true,
    },

    // Customer information
    customerName: {
      type: String,
      trim: true,
      default: "Walk-in Customer",
    },

    customerPhone: {
      type: String,
      trim: true,
    },

    // Number of units or copies
    quantity: {
      type: Number,
      required: true,
      min: 1,
      default: 1,
    },

    // Cybercafe revenue per unit
    serviceFee: {
      type: Number,
      required: true,
      min: 0,
    },

    // External or government charge per transaction
    externalFee: {
      type: Number,
      default: 0,
      min: 0,
    },

    // Total amount charged to the customer
    totalAmount: {
      type: Number,
      required: true,
      min: 0,
    },

    // Employee who recorded the transaction
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
  }
);

// Useful for business-specific daily sales queries
transactionSchema.index({ business: 1, createdAt: -1 });

module.exports = mongoose.model("Transaction", transactionSchema);