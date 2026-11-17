const mongoose = require("mongoose");

const expenseSchema = new mongoose.Schema(
  {
    business: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Business",
      required: true,
      index: true,
    },

    title: {
      type: String,
      required: true,
      trim: true,
    },

    category: {
      type: String,
      enum: [
        "rent",
        "electricity",
        "internet",
        "transport",
        "supplies",
        "maintenance",
        "salaries",
        "other",
      ],
      default: "other",
    },

    amount: {
      type: Number,
      required: true,
      min: 0.01,
    },

    paymentMethod: {
      type: String,
      enum: ["cash", "mpesa", "bank", "other"],
      default: "cash",
    },

    description: {
      type: String,
      trim: true,
    },

    expenseDate: {
      type: Date,
      required: true,
      default: Date.now,
    },

    recordedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
  },
  {
    timestamps: true,
  }
);

expenseSchema.index({ business: 1, expenseDate: -1 });

module.exports = mongoose.model("Expense", expenseSchema);