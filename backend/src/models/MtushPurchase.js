const mongoose = require("mongoose");

const inventoryCategoryValues = [
  "phone_accessory",
  "phone_part",
  "electronics",
  "mens_clothing",
  "womens_clothing",
  "unisex_clothing",
  "mens_shoes",
  "womens_shoes",
  "other",
];

const allocationSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    category: {
      type: String,
      enum: inventoryCategoryValues,
      required: true,
    },
    gender: { type: String, enum: ["mens", "womens", "unisex", "other"] },
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
    size: { type: String, trim: true },
    color: { type: String, trim: true },
    condition: { type: String, trim: true },
    sellableQuantity: { type: Number, required: true, min: 0 },
    unsellableQuantity: { type: Number, required: true, min: 0, default: 0 },
    sellingPrice: { type: Number, min: 0, default: 0 },
    costPerSellablePiece: { type: Number, min: 0, default: 0 },
    allocatedCost: { type: Number, min: 0, default: 0 },
    item: { type: mongoose.Schema.Types.ObjectId, ref: "InventoryItem" },
  },
  { _id: false },
);

const mtushPurchaseSchema = new mongoose.Schema(
  {
    business: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Business",
      required: true,
      index: true,
    },
    purchaseType: { type: String, enum: ["bale", "individual"], required: true },
    supplier: { type: String, trim: true, required: true },
    purchaseDate: { type: Date, required: true },
    description: { type: String, trim: true },
    totalCost: { type: Number, required: true, min: 0 },
    additionalCosts: { type: Number, min: 0, default: 0 },
    totalPurchaseCost: { type: Number, required: true, min: 0 },
    obtainedQuantity: { type: Number, min: 0 },
    sellableQuantity: { type: Number, min: 0 },
    unsellableQuantity: { type: Number, min: 0 },
    sortingDifference: { type: Number, min: 0, default: 0 },
    sortingDifferenceReason: { type: String, trim: true },
    allocations: { type: [allocationSchema], default: undefined },
    item: { type: mongoose.Schema.Types.ObjectId, ref: "InventoryItem" },
    quantity: { type: Number, min: 1 },
    unitBuyingCost: { type: Number, min: 0 },
    recordedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
  },
  { timestamps: true },
);

mtushPurchaseSchema.index({ business: 1, purchaseDate: -1 });
mtushPurchaseSchema.index({ business: 1, purchaseType: 1, createdAt: -1 });

module.exports = mongoose.model("MtushPurchase", mtushPurchaseSchema);
