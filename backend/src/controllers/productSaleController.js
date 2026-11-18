const mongoose = require("mongoose");
const ProductSale = require("../models/ProductSale");
const InventoryItem = require("../models/InventoryItem");
const StockMovement = require("../models/StockMovement");

const parseNumber = (value) => {
  if (
    value === undefined ||
    value === null ||
    (typeof value !== "number" && typeof value !== "string") ||
    (typeof value === "string" && value.trim() === "")
  ) {
    return NaN;
  }

  return Number(value);
};

const escapeRegex = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

const createProductSale = async (req, res) => {
  const body = req.body || {};
  const { itemId, newProduct } = body;
  const hasItemId = itemId !== undefined && itemId !== null && itemId !== "";
  const hasNewProduct = newProduct !== undefined && newProduct !== null;

  if (hasItemId === hasNewProduct) {
    return res.status(400).json({
      success: false,
      message: "Provide either a valid itemId or newProduct, but not both",
    });
  }

  if (hasItemId && !mongoose.Types.ObjectId.isValid(itemId)) {
    return res.status(400).json({
      success: false,
      message: "A valid inventory item ID is required",
    });
  }

  if (
    hasNewProduct &&
    (typeof newProduct !== "object" || Array.isArray(newProduct))
  ) {
    return res.status(400).json({
      success: false,
      message: "New product details must be an object",
    });
  }

  const quantity = parseNumber(body.quantity);
  if (!Number.isSafeInteger(quantity) || quantity < 1) {
    return res.status(400).json({
      success: false,
      message: "Quantity must be a positive whole number",
    });
  }

  const paymentMethod = body.paymentMethod ?? "cash";
  const paymentStatus = body.paymentStatus ?? "paid";
  const paymentMethods = ProductSale.schema.path("paymentMethod").enumValues;
  const paymentStatuses = ProductSale.schema.path("paymentStatus").enumValues;

  if (!paymentMethods.includes(paymentMethod)) {
    return res.status(400).json({
      success: false,
      message: "Invalid payment method",
    });
  }

  if (!paymentStatuses.includes(paymentStatus)) {
    return res.status(400).json({
      success: false,
      message: "Invalid payment status",
    });
  }

  if (paymentStatus === "cancelled") {
    return res.status(400).json({
      success: false,
      message: "Cancelled product sales cannot be recorded",
    });
  }

  let newProductDetails;
  if (hasNewProduct) {
    const name =
      typeof newProduct.name === "string" ? newProduct.name.trim() : "";
    const category = newProduct.category;
    const costPrice = parseNumber(newProduct.costPrice);
    const sellingPrice = parseNumber(newProduct.sellingPrice);
    const openingStock = parseNumber(newProduct.openingStock);
    const reorderLevel =
      newProduct.reorderLevel === undefined ||
      newProduct.reorderLevel === null
        ? 5
        : parseNumber(newProduct.reorderLevel);
    const categories = InventoryItem.schema.path("category").enumValues;

    if (
      !name ||
      typeof category !== "string" ||
      !categories.includes(category) ||
      !Number.isFinite(costPrice) ||
      costPrice < 0 ||
      !Number.isFinite(sellingPrice) ||
      sellingPrice < 0 ||
      !Number.isSafeInteger(openingStock) ||
      openingStock < 1 ||
      !Number.isSafeInteger(reorderLevel) ||
      reorderLevel < 0
    ) {
      return res.status(400).json({
        success: false,
        message: "Invalid new product details",
      });
    }

    if (quantity > openingStock) {
      return res.status(400).json({
        success: false,
        message: "Quantity cannot exceed opening stock",
      });
    }

    if (
      newProduct.sku !== undefined &&
      newProduct.sku !== null &&
      typeof newProduct.sku !== "string"
    ) {
      return res.status(400).json({
        success: false,
        message: "SKU must be a string",
      });
    }

    newProductDetails = {
      name,
      category,
      sku: newProduct.sku,
      costPrice,
      sellingPrice,
      openingStock,
      reorderLevel,
    };
  }

  let session;
  try {
    session = await mongoose.startSession();

    let productSale;
    let product;
    let totalAmount;

    await session.withTransaction(async () => {
      if (newProductDetails) {
        const duplicateProduct = await InventoryItem.findOne({
          business: req.business._id,
          isActive: true,
          name: {
            $regex: `^${escapeRegex(newProductDetails.name)}$`,
            $options: "i",
          },
        }).session(session);

        if (duplicateProduct) {
          const error = new Error(
            "A product with this name already exists. Select it from inventory instead.",
          );
          error.statusCode = 409;
          throw error;
        }

        const [createdProduct] = await InventoryItem.create(
          [
            {
              business: req.business._id,
              name: newProductDetails.name,
              category: newProductDetails.category,
              sku: newProductDetails.sku,
              costPrice: newProductDetails.costPrice,
              sellingPrice: newProductDetails.sellingPrice,
              quantityInStock: newProductDetails.openingStock,
              reorderLevel: newProductDetails.reorderLevel,
              createdBy: req.user._id,
            },
          ],
          { session },
        );
        product = createdProduct;
      } else {
        product = await InventoryItem.findOne({
          _id: itemId,
          business: req.business._id,
          isActive: true,
        }).session(session);

        if (!product) {
          const error = new Error("Active inventory item not found");
          error.statusCode = 404;
          throw error;
        }
      }

      product = await InventoryItem.findOneAndUpdate(
        {
          _id: product._id,
          business: req.business._id,
          isActive: true,
          quantityInStock: { $gte: quantity },
        },
        {
          $inc: { quantityInStock: -quantity },
        },
        {
          new: true,
          session,
        },
      );

      if (!product) {
        const error = new Error("Insufficient stock available");
        error.statusCode = 400;
        throw error;
      }

      const newQuantity = product.quantityInStock;
      const previousQuantity = newQuantity + quantity;
      const sellingPrice = product.sellingPrice;
      const profitPerUnit = sellingPrice - product.costPrice;
      const profitAmount = profitPerUnit * quantity;
      totalAmount = sellingPrice * quantity;

      await StockMovement.create(
        [
          {
            business: req.business._id,
            item: product._id,
            type: "stock_out",
            quantity,
            previousQuantity,
            newQuantity,
            reason: "Product sale",
            recordedBy: req.user._id,
          },
        ],
        { session },
      );

      const [createdSale] = await ProductSale.create(
        [
          {
            business: req.business._id,
            item: product._id,
            productName: product.name,
            quantity,
            sellingPrice,
            profitPerUnit,
            totalAmount,
            customerName: body.customerName,
            customerPhone: body.customerPhone,
            recordedBy: req.user._id,
            paymentMethod,
            paymentStatus,
            notes: body.notes,
          },
        ],
        { session },
      );
      productSale = createdSale;
    });

    return res.status(201).json({
      success: true,
      message: "Product sale recorded successfully",
      data: {
        sale: productSale,
        product,
        calculation: {
          quantity,
          sellingPrice: productSale.sellingPrice,
          totalAmount,
          profitAmount,
        },
      },
    });
  } catch (error) {
    console.error("Create product sale error:", error);

    return res.status(error.statusCode || 500).json({
      success: false,
      message: error.statusCode ? error.message : "Failed to record product sale",
    });
  } finally {
    if (session) {
      await session.endSession();
    }
  }
};

const getProductSales = async (req, res) => {
  try {
    const sales = await ProductSale.find({
      business: req.business._id,
    })
      .populate("item", "name category")
      .populate("recordedBy", "fullName")
      .sort({ createdAt: -1 });

    return res.status(200).json({
      success: true,
      count: sales.length,
      sales,
    });
  } catch (error) {
    console.error("Get product sales error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to retrieve product sales",
    });
  }
};

module.exports = {
  createProductSale,
  getProductSales,
};
