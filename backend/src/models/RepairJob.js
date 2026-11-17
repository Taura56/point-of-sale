const mongoose = require("mongoose");

const repairJobSchema = new mongoose.Schema(
  {
    // Business responsible for the repair
    business: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Business",
      required: true,
      index: true,
    },

    repairName: {
      type: String,
      trim: true,
    },

    // Customer details
    customerName: {
      type: String,
      trim: true,
    },

    customerPhone: {
      type: String,
      trim: true,
    },

    // Device information
    deviceType: {
      type: String,
      trim: true,
    },

    brand: {
      type: String,
      trim: true,
    },

    model: {
      type: String,
      trim: true,
    },

    // Reported problem
    reportedProblem: {
      type: String,
      trim: true,
    },

    diagnosis: {
      type: String,
      trim: true,
    },

    // Repair financial details
    estimatedCost: {
      type: Number,
      default: 0,
      min: 0,
    },

    repairCost: {
      type: Number,
      default: 0,
      min: 0,
    },

    amountPaid: {
      type: Number,
      default: 0,
      min: 0,
    },

    // Repair progress
    status: {
      type: String,
      enum: [
        "received",
        "diagnosing",
        "waiting_for_approval",
        "waiting_for_parts",
        "in_progress",
        "completed",
        "collected",
        "cancelled",
      ],
      default: "received",
    },

    // Employee handling the repair
    receivedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    assignedTo: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
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

// Each business has its own repair job records
repairJobSchema.index({ business: 1, createdAt: -1 });

module.exports = mongoose.model("RepairJob", repairJobSchema);