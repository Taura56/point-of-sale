const mongoose = require("mongoose");

const paymentSchema = new mongoose.Schema(
  {
    amount: { type: Number, required: true, min: 0 },
    paymentMethod: { type: String, enum: ["cash", "mpesa"], required: true },
    idempotencyKey: { type: String, required: true, trim: true },
    paidAt: { type: Date, default: Date.now },
    recordedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
  },
  { _id: true },
);

const orderItemSchema = new mongoose.Schema(
  {
    item: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "InventoryItem",
      required: true,
    },
    productName: { type: String, required: true, trim: true },
    quantity: { type: Number, required: true, min: 1 },
    unitSellingPrice: { type: Number, required: true, min: 0 },
    unitCost: { type: Number, required: true, min: 0 },
    lineTotal: { type: Number, required: true, min: 0 },
  },
  { _id: false },
);

const installmentOrderSchema = new mongoose.Schema(
  {
    business: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Business",
      required: true,
      index: true,
    },
    customerName: { type: String, trim: true, default: "Walk-in Customer" },
    customerPhone: { type: String, trim: true },
    items: { type: [orderItemSchema], required: true },
    totalAmount: { type: Number, required: true, min: 0 },
    amountPaid: { type: Number, required: true, min: 0, default: 0 },
    status: {
      type: String,
      enum: ["pending", "awaiting_collection", "collected", "cancelled"],
      default: "pending",
      index: true,
    },
    payments: { type: [paymentSchema], default: [] },
    collectedAt: { type: Date },
    cancelledAt: { type: Date },
    recordedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
  },
  { timestamps: true },
);

installmentOrderSchema.index({ business: 1, createdAt: -1 });
installmentOrderSchema.index({ business: 1, status: 1, createdAt: -1 });
installmentOrderSchema.index(
  { business: 1, "payments.idempotencyKey": 1 },
  { unique: true, sparse: true },
);

module.exports = mongoose.model("MtushInstallmentOrder", installmentOrderSchema);
