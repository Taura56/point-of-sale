const mongoose = require("mongoose");
const InventoryItem = require("../models/InventoryItem");
const StockMovement = require("../models/StockMovement");

// Register a new inventory item
const createInventoryItem = async (req, res) => {
  let session;
  try {
    const {
      name,
      category,
      gender,
      productType,
      size,
      color,
      condition,
      sku,
      costPrice,
      sellingPrice,
      quantityInStock,
      reorderLevel,
    } = req.body;

    if (!name || costPrice === undefined || sellingPrice === undefined) {
      return res.status(400).json({
        success: false,
        message: "Name, cost price and selling price are required",
      });
    }

    const cost = Number(costPrice);
    const selling = Number(sellingPrice);
    const quantity = Number(quantityInStock ?? 0);
    const reorder = Number(reorderLevel ?? 5);

    if (
      !Number.isFinite(cost) || cost < 0 ||
      !Number.isFinite(selling) || selling < 0 ||
      !Number.isInteger(quantity) || quantity < 0 ||
      !Number.isInteger(reorder) || reorder < 0
    ) {
      return res.status(400).json({
        success: false,
        message: "Invalid price, stock quantity or reorder level",
      });
    }

    for (const [field, value] of [
      ["category", category],
      ["gender", gender],
      ["productType", productType],
    ]) {
      if (
        value !== undefined &&
        !InventoryItem.schema.path(field).enumValues.includes(value)
      ) {
        return res.status(400).json({
          success: false,
          message: `Invalid ${field}`,
        });
      }
    }

    for (const [field, value] of [
      ["size", size],
      ["color", color],
      ["condition", condition],
    ]) {
      if (value !== undefined && value !== null && typeof value !== "string") {
        return res.status(400).json({
          success: false,
          message: `Invalid ${field}`,
        });
      }
    }

    session = await mongoose.startSession();
    let item;
    await session.withTransaction(async () => {
      [item] = await InventoryItem.create(
        [
          {
            business: req.business._id,
            name,
            category,
            gender,
            productType,
            size,
            color,
            condition,
            sku,
            costPrice: cost,
            sellingPrice: selling,
            quantityInStock: quantity,
            reorderLevel: reorder,
            createdBy: req.user._id,
          },
        ],
        { session },
      );

      if (req.business.businessType === "mtush" && quantity > 0) {
        await StockMovement.create(
          [
            {
              business: req.business._id,
              item: item._id,
              type: "stock_in",
              quantity,
              previousQuantity: 0,
              newQuantity: quantity,
              reason: "Mtush inventory stock added",
              recordedBy: req.user._id,
            },
          ],
          { session },
        );
      }
    });

    return res.status(201).json({
      success: true,
      message: "Inventory item created successfully",
      item,
    });
  } catch (error) {
    console.error("Create inventory item error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to create inventory item",
    });
  } finally {
    if (session) await session.endSession();
  }
};

// Get all inventory items belonging to the current business
const getInventoryItems = async (req, res) => {
  try {
    const items = await InventoryItem.find({
      business: req.business._id,
      isActive: true,
    }).sort({ createdAt: -1 });

    return res.status(200).json({
      success: true,
      count: items.length,
      items,
    });
  } catch (error) {
    console.error("Get inventory items error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to retrieve inventory items",
    });
  }
};

// Get inventory items that need restocking
const getLowStockItems = async (req, res) => {
  try {
    const stockThreshold =
      req.business.businessType === "mtush"
        ? {
            $expr: {
              $lte: [
                {
                  $subtract: [
                    "$quantityInStock",
                    { $ifNull: ["$reservedQuantity", 0] },
                  ],
                },
                "$reorderLevel",
              ],
            },
          }
        : {
            $expr: {
              $lte: ["$quantityInStock", "$reorderLevel"],
            },
          };
    const items = await InventoryItem.find({
      business: req.business._id,
      isActive: true,
      ...stockThreshold,
    }).sort({ quantityInStock: 1 });
    const responseItems =
      req.business.businessType === "mtush"
        ? items.map((item) => ({
            ...item.toObject(),
            availableQuantity:
              item.quantityInStock - (item.reservedQuantity || 0),
          }))
        : items;

    return res.status(200).json({
      success: true,
      count: items.length,
      items: responseItems,
    });
  } catch (error) {
    console.error("Get low stock items error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to retrieve low-stock items",
    });
  }
};

// Update inventory item details
const updateInventoryItem = async (req, res) => {
  const body = req.body ?? {};
  const {
    name,
    category,
    gender,
    productType,
    size,
    color,
    condition,
    sku,
    costPrice,
    sellingPrice,
    quantityInStock,
    reorderLevel,
    isActive,
  } = body;

  if (!mongoose.Types.ObjectId.isValid(req.params.itemId)) {
    return res.status(400).json({
      success: false,
      message: "A valid inventory item ID is required",
    });
  }

  if (name !== undefined && (typeof name !== "string" || !name.trim())) {
    return res.status(400).json({
      success: false,
      message: "Name cannot be empty",
    });
  }

  if (
    category !== undefined &&
    !InventoryItem.schema.path("category").enumValues.includes(category)
  ) {
    return res.status(400).json({
      success: false,
      message: "Invalid category",
    });
  }

  for (const [field, value] of [
    ["gender", gender],
    ["productType", productType],
  ]) {
    if (
      value !== undefined &&
      value !== null &&
      !InventoryItem.schema.path(field).enumValues.includes(value)
    ) {
      return res.status(400).json({
        success: false,
        message: `Invalid ${field}`,
      });
    }
  }

  for (const [field, value] of [
    ["size", size],
    ["color", color],
    ["condition", condition],
  ]) {
    if (value !== undefined && value !== null && typeof value !== "string") {
      return res.status(400).json({
        success: false,
        message: `Invalid ${field}`,
      });
    }
  }

  if (
    sku !== undefined &&
    sku !== null &&
    typeof sku !== "string"
  ) {
    return res.status(400).json({
      success: false,
      message: "Invalid SKU",
    });
  }

  if (isActive !== undefined && typeof isActive !== "boolean") {
    return res.status(400).json({
      success: false,
      message: "Invalid active status",
    });
  }

  const updates = [
    ["costPrice", costPrice, false],
    ["sellingPrice", sellingPrice, false],
    ["quantityInStock", quantityInStock, true],
    ["reorderLevel", reorderLevel, true],
  ];
  const parsedUpdates = {};

  for (const [field, value, mustBeInteger] of updates) {
    if (value === undefined) continue;

    const number = Number(value);
    if (
      value === null ||
      (typeof value === "string" && value.trim() === "") ||
      !Number.isFinite(number) ||
      number < 0 ||
      (mustBeInteger && !Number.isInteger(number))
    ) {
      return res.status(400).json({
        success: false,
        message: `Invalid ${field}`,
      });
    }

    parsedUpdates[field] = number;
  }

  let session;
  try {
    session = await mongoose.startSession();

    let updatedItem;
    await session.withTransaction(async () => {
      const item = await InventoryItem.findOne({
        _id: req.params.itemId,
        business: req.business._id,
      }).session(session);

      if (!item) {
        const error = new Error("Inventory item not found");
        error.statusCode = 404;
        throw error;
      }

      if (name !== undefined) item.name = name.trim();
      if (category !== undefined) item.category = category;
      if (gender !== undefined) item.gender = gender;
      if (productType !== undefined) item.productType = productType;
      if (size !== undefined) item.size = size?.trim() ?? "";
      if (color !== undefined) item.color = color?.trim() ?? "";
      if (condition !== undefined) item.condition = condition;
      if (sku !== undefined) item.sku = sku?.trim() ?? "";
      if (isActive !== undefined) item.isActive = isActive;

      const previousQuantity = item.quantityInStock;
      for (const [field, value] of Object.entries(parsedUpdates)) {
        item[field] = value;
      }

      if (item.quantityInStock < item.reservedQuantity) {
        const error = new Error(
          "Physical stock cannot be lower than reserved stock",
        );
        error.statusCode = 400;
        throw error;
      }

      await item.save({ session });

      if (
        quantityInStock !== undefined &&
        previousQuantity !== item.quantityInStock
      ) {
        await StockMovement.create(
          [
            {
              business: req.business._id,
              item: item._id,
              type: "adjustment",
              quantity: Math.abs(item.quantityInStock - previousQuantity),
              previousQuantity,
              newQuantity: item.quantityInStock,
              reason: "Inventory item edited",
              recordedBy: req.user._id,
            },
          ],
          { session },
        );
      }

      updatedItem = item;
    });

    return res.status(200).json({
      success: true,
      message: "Inventory item updated successfully",
      item: updatedItem,
    });
  } catch (error) {
    console.error("Update inventory item error:", error);

    return res.status(error.statusCode || 500).json({
      success: false,
      message: error.statusCode
        ? error.message
        : "Failed to update inventory item",
    });
  } finally {
    if (session) {
      await session.endSession();
    }
  }
};

const deleteInventoryItem = async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.itemId)) {
      return res.status(400).json({
        success: false,
        message: "A valid inventory item ID is required",
      });
    }

    const item = await InventoryItem.findOneAndUpdate(
      {
        _id: req.params.itemId,
        business: req.business._id,
        isActive: true,
      },
      { $set: { isActive: false } },
      { new: true },
    );

    if (!item) {
      return res.status(404).json({
        success: false,
        message: "Inventory item not found",
      });
    }

    return res.status(200).json({
      success: true,
      message: "Inventory item removed successfully",
      item,
    });
  } catch (error) {
    console.error("Delete inventory item error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to remove inventory item",
    });
  }
};

module.exports = {
  createInventoryItem,
  getInventoryItems,
  getLowStockItems,
  updateInventoryItem,
  deleteInventoryItem,
};