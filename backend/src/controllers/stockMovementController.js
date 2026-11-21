const mongoose = require("mongoose");
const InventoryItem = require("../models/InventoryItem");
const StockMovement = require("../models/StockMovement");

const recordStockMovement = async (req, res) => {
  const { itemId, type, quantity, reason } = req.body;

  if (!itemId || !mongoose.Types.ObjectId.isValid(itemId)) {
    return res.status(400).json({
      success: false,
      message: "A valid inventory item ID is required",
    });
  }

  if (!["stock_in", "stock_out"].includes(type)) {
    return res.status(400).json({
      success: false,
      message: "Movement type must be stock_in or stock_out",
    });
  }

  if (type === "stock_in" && req.business.businessType === "mtush") {
    return res.status(403).json({
      success: false,
      message: "Mtush stock intake must be recorded through the purchase APIs",
    });
  }

  const amount = Number(quantity);

  if (!Number.isInteger(amount) || amount <= 0) {
    return res.status(400).json({
      success: false,
      message: "Quantity must be a positive whole number",
    });
  }

  const session = await mongoose.startSession();

  try {
    let movement;

    await session.withTransaction(async () => {
      const item = await InventoryItem.findOne({
        _id: itemId,
        business: req.business._id,
        isActive: true,
      }).session(session);

      if (!item) {
        const error = new Error("Inventory item not found");
        error.statusCode = 404;
        throw error;
      }

      const previousQuantity = item.quantityInStock;

      let newQuantity;

      if (type === "stock_in") {
        newQuantity = previousQuantity + amount;
      } else {
        const reservedQuantity =
          req.business.businessType === "mtush"
            ? item.reservedQuantity || 0
            : 0;
        if (amount > previousQuantity - reservedQuantity) {
          const error = new Error(
            reservedQuantity
              ? "Stock reduction cannot consume reserved quantity"
              : "Insufficient stock available",
          );
          error.statusCode = 400;
          throw error;
        }

        newQuantity = previousQuantity - amount;
      }

      item.quantityInStock = newQuantity;
      await item.save({ session });

      const records = await StockMovement.create(
        [
          {
            business: req.business._id,
            item: item._id,
            type,
            quantity: amount,
            previousQuantity,
            newQuantity,
            reason,
            recordedBy: req.user._id,
          },
        ],
        { session }
      );

      movement = records[0];
    });

    return res.status(201).json({
      success: true,
      message: "Stock movement recorded successfully",
      movement,
    });
  } catch (error) {
    console.error("Stock movement error:", error);

    return res.status(error.statusCode || 500).json({
      success: false,
      message: error.statusCode
        ? error.message
        : "Failed to record stock movement",
    });
  } finally {
    await session.endSession();
  }
};

// Get stock movement history for the current business
const getStockMovements = async (req, res) => {
  try {
    const movements = await StockMovement.find({
      business: req.business._id,
    })
      .populate("item", "name category")
      .populate("recordedBy", "fullName")
      .sort({ createdAt: -1 });

    return res.status(200).json({
      success: true,
      count: movements.length,
      movements,
    });
  } catch (error) {
    console.error("Get stock movements error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to retrieve stock movement history",
    });
  }
};

module.exports = {
  recordStockMovement,
  getStockMovements,
};