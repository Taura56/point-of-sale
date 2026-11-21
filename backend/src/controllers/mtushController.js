const mongoose = require("mongoose");
const InventoryItem = require("../models/InventoryItem");
const MtushPurchase = require("../models/MtushPurchase");
const MtushInstallmentOrder = require("../models/MtushInstallmentOrder");
const ProductSale = require("../models/ProductSale");
const StockMovement = require("../models/StockMovement");

const categories = InventoryItem.schema.path("category").enumValues;
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
const validDate = (value) => {
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
};
const asError = (message, statusCode = 400) =>
  Object.assign(new Error(message), { statusCode });
const rounded = (value) => Math.round((value + Number.EPSILON) * 100) / 100;
const validOrderId = (id) => mongoose.Types.ObjectId.isValid(id);
const identityFields = [
  "category",
  "gender",
  "productType",
  "size",
  "color",
  "condition",
];
const productIdentity = (allocation) => {
  const identity = {
    business: allocation.business,
    name: allocation.name,
    isActive: true,
  };
  for (const field of identityFields) {
    identity[field] = allocation[field] ?? null;
  }
  return identity;
};
const findOrCreateAllocatedProduct = async (
  allocation,
  allocatedCost,
  session,
  req,
) => {
  let product = await InventoryItem.findOne(productIdentity(allocation)).session(
    session,
  );
  const addedQuantity = allocation.sellableQuantity;
  if (!addedQuantity) return product;

  if (!product) {
    const [created] = await InventoryItem.create(
      [
        {
          business: req.business._id,
          name: allocation.name,
          category: allocation.category,
          gender: allocation.gender,
          productType: allocation.productType,
          size: allocation.size,
          color: allocation.color,
          condition: allocation.condition,
          costPrice: allocatedCost / addedQuantity,
          sellingPrice: allocation.sellingPrice,
          quantityInStock: addedQuantity,
          createdBy: req.user._id,
        },
      ],
      { session },
    );
    product = created;
    await StockMovement.create(
      [
        {
          business: req.business._id,
          item: product._id,
          type: "stock_in",
          quantity: addedQuantity,
          previousQuantity: 0,
          newQuantity: addedQuantity,
          reason: "Mtush bale purchase",
          recordedBy: req.user._id,
        },
      ],
      { session },
    );
    return product;
  }

  const previousQuantity = product.quantityInStock;
  const nextQuantity = previousQuantity + addedQuantity;
  const nextCostPrice =
    nextQuantity === 0
      ? product.costPrice
      : (previousQuantity * product.costPrice + allocatedCost) / nextQuantity;
  product = await InventoryItem.findOneAndUpdate(
    { _id: product._id, business: req.business._id, isActive: true },
    {
      $inc: { quantityInStock: addedQuantity },
      $set: { costPrice: nextCostPrice },
    },
    { new: true, session },
  );
  if (!product) throw asError("Matching inventory item is unavailable", 409);

  await StockMovement.create(
    [
      {
        business: req.business._id,
        item: product._id,
        type: "stock_in",
        quantity: addedQuantity,
        previousQuantity,
        newQuantity: nextQuantity,
        reason: "Mtush bale purchase",
        recordedBy: req.user._id,
      },
    ],
    { session },
  );
  return product;
};

const getPurchases = async (req, res) => {
  try {
    const purchases = await MtushPurchase.find({
      business: req.business._id,
    })
      .populate("item", "name category gender productType size color condition")
      .populate("recordedBy", "fullName")
      .sort({ purchaseDate: -1, createdAt: -1 });
    return res.status(200).json({ success: true, count: purchases.length, purchases });
  } catch (error) {
    console.error("Get Mtush purchases error:", error);
    return res.status(500).json({ success: false, message: "Failed to retrieve Mtush purchases" });
  }
};

const createBalePurchase = async (req, res) => {
  const body = req.body || {};
  const purchaseDate = validDate(body.purchaseDate);
  const totalCost = parseNumber(body.totalCost);
  const additionalCosts =
    body.additionalCosts === undefined ? 0 : parseNumber(body.additionalCosts);
  const obtainedQuantity = parseNumber(body.obtainedQuantity);
  const sortingDifference =
    body.sortingDifference === undefined ? 0 : parseNumber(body.sortingDifference);
  if (
    typeof body.supplier !== "string" ||
    !body.supplier.trim() ||
    !purchaseDate ||
    !Number.isFinite(totalCost) ||
    totalCost < 0 ||
    !Number.isFinite(additionalCosts) ||
    additionalCosts < 0 ||
    !Number.isSafeInteger(obtainedQuantity) ||
    obtainedQuantity < 1 ||
    !Number.isSafeInteger(sortingDifference) ||
    sortingDifference < 0 ||
    (body.sortingDifferenceReason !== undefined &&
      typeof body.sortingDifferenceReason !== "string") ||
    !Array.isArray(body.allocations) ||
    body.allocations.length === 0
  ) {
    return res.status(400).json({ success: false, message: "Invalid bale purchase details" });
  }

  let sellableQuantity = 0;
  let unsellableQuantity = 0;
  const allocations = [];
  for (const entry of body.allocations) {
    const name = typeof entry?.name === "string" ? entry.name.trim() : "";
    const sellable = parseNumber(entry?.sellableQuantity);
    const unsellable =
      entry?.unsellableQuantity === undefined
        ? 0
        : parseNumber(entry.unsellableQuantity);
    const sellingPrice =
      entry?.sellingPrice === undefined ? 0 : parseNumber(entry.sellingPrice);
    if (
      !name ||
      !categories.includes(entry.category) ||
      !Number.isSafeInteger(sellable) ||
      sellable < 0 ||
      !Number.isSafeInteger(unsellable) ||
      unsellable < 0 ||
      !Number.isFinite(sellingPrice) ||
      sellingPrice < 0
    ) {
      return res.status(400).json({ success: false, message: "Invalid bale allocation" });
    }
    for (const field of ["gender", "productType"]) {
      const path = InventoryItem.schema.path(field);
      if (entry[field] !== undefined && !path.enumValues.includes(entry[field])) {
        return res.status(400).json({ success: false, message: `Invalid allocation ${field}` });
      }
    }
    for (const field of ["size", "color", "condition"]) {
      if (entry[field] !== undefined && typeof entry[field] !== "string") {
        return res.status(400).json({ success: false, message: `Invalid allocation ${field}` });
      }
    }
    sellableQuantity += sellable;
    unsellableQuantity += unsellable;
    allocations.push({
      name,
      category: entry.category,
      gender: entry.gender,
      productType: entry.productType,
      size: entry.size?.trim(),
      color: entry.color?.trim(),
      condition: entry.condition,
      sellableQuantity: sellable,
      unsellableQuantity: unsellable,
      sellingPrice,
    });
  }
  if (
    sellableQuantity < 1 ||
    sellableQuantity + unsellableQuantity + sortingDifference !== obtainedQuantity
  ) {
    return res.status(400).json({
      success: false,
      message: "Sellable, unsellable and sortingDifference quantities must total obtainedQuantity",
    });
  }

  const totalPurchaseCost = rounded(totalCost + additionalCosts);
  let session;
  try {
    session = await mongoose.startSession();
    let purchase;
    await session.withTransaction(async () => {
      let remainingCents = Math.round(totalPurchaseCost * 100);
      let remainingPieces = sellableQuantity;
      for (let index = 0; index < allocations.length; index += 1) {
        const allocation = allocations[index];
        const quantity = allocation.sellableQuantity;
        const allocatedCents =
          quantity === remainingPieces
            ? remainingCents
            : Math.floor((remainingCents * quantity) / remainingPieces);
        const allocatedCost = allocatedCents / 100;
        allocation.allocatedCost = allocatedCost;
        allocation.costPerSellablePiece = quantity
          ? allocatedCost / quantity
          : 0;
        allocation.item = (
          await findOrCreateAllocatedProduct(
            { ...allocation, business: req.business._id },
            allocatedCost,
            session,
            req,
          )
        )?._id;
        remainingCents -= allocatedCents;
        remainingPieces -= quantity;
      }
      [purchase] = await MtushPurchase.create(
        [
          {
            business: req.business._id,
            purchaseType: "bale",
            supplier: body.supplier.trim(),
            purchaseDate,
            description: body.description,
            totalCost,
            additionalCosts,
            totalPurchaseCost,
            obtainedQuantity,
            sellableQuantity,
            unsellableQuantity,
            sortingDifference,
            sortingDifferenceReason: body.sortingDifferenceReason,
            allocations,
            recordedBy: req.user._id,
          },
        ],
        { session },
      );
    });
    return res.status(201).json({
      success: true,
      message: "Bale purchase recorded successfully",
      purchase,
    });
  } catch (error) {
    console.error("Create Mtush bale purchase error:", error);
    return res.status(error.statusCode || 500).json({
      success: false,
      message: error.statusCode ? error.message : "Failed to record bale purchase",
    });
  } finally {
    if (session) await session.endSession();
  }
};

const createIndividualPurchase = async (req, res) => {
  const body = req.body || {};
  const quantity = parseNumber(body.quantity);
  const unitBuyingCost = parseNumber(body.unitBuyingCost);
  const purchaseDate = validDate(body.purchaseDate);
  if (
    !mongoose.Types.ObjectId.isValid(body.itemId) ||
    !Number.isSafeInteger(quantity) ||
    quantity < 1 ||
    !Number.isFinite(unitBuyingCost) ||
    unitBuyingCost < 0 ||
    typeof body.supplier !== "string" ||
    !body.supplier.trim() ||
    !purchaseDate
  ) {
    return res.status(400).json({ success: false, message: "Invalid individual purchase details" });
  }
  const totalPurchaseCost = rounded(quantity * unitBuyingCost);
  let session;
  try {
    session = await mongoose.startSession();
    let purchase;
    await session.withTransaction(async () => {
      const item = await InventoryItem.findOne({
        _id: body.itemId,
        business: req.business._id,
        isActive: true,
      }).session(session);
      if (!item) throw asError("Active inventory item not found", 404);
      const previousQuantity = item.quantityInStock;
      const nextQuantity = previousQuantity + quantity;
      const nextCostPrice =
        nextQuantity === 0
          ? unitBuyingCost
          : (previousQuantity * item.costPrice + totalPurchaseCost) / nextQuantity;
      await InventoryItem.updateOne(
        { _id: item._id, business: req.business._id },
        {
          $inc: { quantityInStock: quantity },
          $set: { costPrice: nextCostPrice },
        },
        { session },
      );
      await StockMovement.create(
        [
          {
            business: req.business._id,
            item: item._id,
            type: "stock_in",
            quantity,
            previousQuantity,
            newQuantity: nextQuantity,
            reason: "Mtush individual purchase",
            recordedBy: req.user._id,
          },
        ],
        { session },
      );
      [purchase] = await MtushPurchase.create(
        [
          {
            business: req.business._id,
            purchaseType: "individual",
            supplier: body.supplier.trim(),
            purchaseDate,
            description: body.description,
            totalCost: totalPurchaseCost,
            additionalCosts: 0,
            totalPurchaseCost,
            item: item._id,
            quantity,
            unitBuyingCost,
            recordedBy: req.user._id,
          },
        ],
        { session },
      );
    });
    return res.status(201).json({
      success: true,
      message: "Individual stock purchase recorded successfully",
      purchase,
    });
  } catch (error) {
    console.error("Create Mtush individual purchase error:", error);
    return res.status(error.statusCode || 500).json({
      success: false,
      message: error.statusCode ? error.message : "Failed to record individual purchase",
    });
  } finally {
    if (session) await session.endSession();
  }
};

const reserveStock = async (itemId, quantity, businessId, session) => {
  const product = await InventoryItem.findOneAndUpdate(
    {
      _id: itemId,
      business: businessId,
      isActive: true,
      $expr: {
        $gte: [
          {
            $subtract: [
              "$quantityInStock",
              { $ifNull: ["$reservedQuantity", 0] },
            ],
          },
          quantity,
        ],
      },
    },
    { $inc: { reservedQuantity: quantity } },
    { new: true, session },
  );
  if (!product) throw asError("Product not found or insufficient available stock");
  return product;
};

const createInstallmentOrder = async (req, res) => {
  const body = req.body || {};
  const customerName =
    typeof body.customerName === "string" ? body.customerName.trim() : "";
  const customerPhone =
    body.customerPhone === undefined || body.customerPhone === null
      ? ""
      : typeof body.customerPhone === "string"
        ? body.customerPhone.trim()
        : null;
  if (!customerName || customerPhone === null) {
    return res.status(400).json({
      success: false,
      message: "A customer name is required and phone number must be text",
    });
  }
  if (!Array.isArray(body.items) || body.items.length === 0) {
    return res.status(400).json({ success: false, message: "At least one order item is required" });
  }
  const items = [];
  const quantitiesByItem = new Map();
  for (const entry of body.items) {
    const quantity = parseNumber(entry?.quantity);
    const unitSellingPrice = parseNumber(entry?.unitSellingPrice);
    if (
      !mongoose.Types.ObjectId.isValid(entry?.itemId) ||
      !Number.isSafeInteger(quantity) ||
      quantity < 1 ||
      !Number.isFinite(unitSellingPrice) ||
      unitSellingPrice < 0
    ) {
      return res.status(400).json({ success: false, message: "Invalid installment order item" });
    }
    const key = String(entry.itemId);
    quantitiesByItem.set(key, (quantitiesByItem.get(key) || 0) + quantity);
    items.push({ itemId: entry.itemId, quantity, unitSellingPrice });
  }

  const initialPayment = body.initialPayment;
  const initialAmount =
    initialPayment === undefined ? 0 : rounded(parseNumber(initialPayment.amount));
  if (
    initialPayment !== undefined &&
    (!initialPayment ||
      typeof initialPayment !== "object" ||
      !Number.isFinite(initialAmount) ||
      initialAmount < 0 ||
      !["cash", "mpesa"].includes(initialPayment.paymentMethod) ||
      typeof initialPayment.idempotencyKey !== "string" ||
      !initialPayment.idempotencyKey.trim())
  ) {
    return res.status(400).json({ success: false, message: "Invalid initial payment" });
  }

  let session;
  try {
    session = await mongoose.startSession();
    let order;
    await session.withTransaction(async () => {
      if (initialAmount > 0) {
        const duplicateKey = await MtushInstallmentOrder.findOne({
          business: req.business._id,
          "payments.idempotencyKey": initialPayment.idempotencyKey.trim(),
        }).session(session);
        if (duplicateKey) throw asError("Payment idempotency key already exists", 409);
      }
      const products = new Map();
      for (const [itemId, quantity] of quantitiesByItem) {
        const product = await reserveStock(
          itemId,
          quantity,
          req.business._id,
          session,
        );
        products.set(itemId, product);
      }
      const orderItems = items.map((entry) => {
        const product = products.get(String(entry.itemId));
        return {
          item: product._id,
          productName: product.name,
          quantity: entry.quantity,
          unitSellingPrice: entry.unitSellingPrice,
          unitCost: product.costPrice,
          lineTotal: rounded(entry.quantity * entry.unitSellingPrice),
        };
      });
      const totalAmount = rounded(
        orderItems.reduce((sum, entry) => sum + entry.lineTotal, 0),
      );
      if (initialAmount > totalAmount) throw asError("Payment exceeds order balance");
      const payments =
        initialAmount > 0
          ? [
              {
                amount: initialAmount,
                paymentMethod: initialPayment.paymentMethod,
                idempotencyKey: initialPayment.idempotencyKey.trim(),
                recordedBy: req.user._id,
              },
            ]
          : [];
      [order] = await MtushInstallmentOrder.create(
        [
          {
            business: req.business._id,
            customerName,
            ...(customerPhone ? { customerPhone } : {}),
            items: orderItems,
            totalAmount,
            amountPaid: initialAmount,
            status:
              initialAmount === totalAmount
                ? "awaiting_collection"
                : "pending",
            payments,
            recordedBy: req.user._id,
          },
        ],
        { session },
      );
    });
    return res.status(201).json({
      success: true,
      message: "Installment order created successfully",
      order,
      balanceDue: rounded(order.totalAmount - order.amountPaid),
    });
  } catch (error) {
    console.error("Create Mtush installment order error:", error);
    return res.status(error.statusCode || (error.code === 11000 ? 409 : 500)).json({
      success: false,
      message: error.statusCode
        ? error.message
        : error.code === 11000
          ? "Payment idempotency key already exists"
          : "Failed to create installment order",
    });
  } finally {
    if (session) await session.endSession();
  }
};

const getInstallmentOrders = async (req, res) => {
  try {
    const filter = { business: req.business._id };
    if (req.query.status) {
      if (!["pending", "awaiting_collection", "collected", "cancelled"].includes(req.query.status)) {
        return res.status(400).json({ success: false, message: "Invalid order status" });
      }
      filter.status = req.query.status;
    }
    const orders = await MtushInstallmentOrder.find(filter)
      .populate("items.item", "name category gender productType size color condition")
      .populate("payments.recordedBy", "fullName")
      .populate("recordedBy", "fullName")
      .sort({ createdAt: -1 });
    return res.status(200).json({ success: true, count: orders.length, orders });
  } catch (error) {
    console.error("Get Mtush installment orders error:", error);
    return res.status(500).json({ success: false, message: "Failed to retrieve installment orders" });
  }
};

const addInstallmentPayment = async (req, res) => {
  const { amount, paymentMethod, idempotencyKey, paymentDate } = req.body || {};
  const parsedAmount = rounded(parseNumber(amount));
  const paidAt = paymentDate === undefined ? undefined : validDate(paymentDate);
  if (
    !validOrderId(req.params.orderId) ||
    !Number.isFinite(parsedAmount) ||
    parsedAmount <= 0 ||
    !["cash", "mpesa"].includes(paymentMethod) ||
    typeof idempotencyKey !== "string" ||
    !idempotencyKey.trim() ||
    (paymentDate !== undefined && (!paidAt || typeof paymentDate !== "string"))
  ) {
    return res.status(400).json({ success: false, message: "Invalid installment payment" });
  }
  let session;
  try {
    session = await mongoose.startSession();
    let order;
    let replayed = false;
    await session.withTransaction(async () => {
      order = await MtushInstallmentOrder.findOne({
        _id: req.params.orderId,
        business: req.business._id,
      }).session(session);
      if (!order) throw asError("Installment order not found", 404);
      const existingPayment = order.payments.find(
        (payment) => payment.idempotencyKey === idempotencyKey.trim(),
      );
      if (existingPayment) {
        if (
          existingPayment.amount !== parsedAmount ||
          existingPayment.paymentMethod !== paymentMethod ||
          (paidAt &&
            new Date(existingPayment.paidAt).getTime() !== paidAt.getTime())
        ) {
          throw asError("Idempotency key was already used with different payment details", 409);
        }
        replayed = true;
        return;
      }
      const reusedKey = await MtushInstallmentOrder.findOne({
        _id: { $ne: order._id },
        business: req.business._id,
        "payments.idempotencyKey": idempotencyKey.trim(),
      }).session(session);
      if (reusedKey) throw asError("Payment idempotency key already exists", 409);
      if (order.status !== "pending") {
        throw asError("Payments can only be added to pending orders", 409);
      }
      if (parsedAmount > order.totalAmount - order.amountPaid) {
        throw asError("Payment exceeds order balance");
      }
      order.payments.push({
        amount: parsedAmount,
        paymentMethod,
        idempotencyKey: idempotencyKey.trim(),
        ...(paidAt ? { paidAt } : {}),
        recordedBy: req.user._id,
      });
      order.amountPaid = rounded(order.amountPaid + parsedAmount);
      if (order.amountPaid === order.totalAmount) order.status = "awaiting_collection";
      await order.save({ session });
    });
    return res.status(200).json({
      success: true,
      message: replayed ? "Payment already recorded" : "Installment payment recorded successfully",
      order,
      payment: order.payments.find(
        (entry) => entry.idempotencyKey === idempotencyKey.trim(),
      ),
      balanceDue: rounded(order.totalAmount - order.amountPaid),
      replayed,
    });
  } catch (error) {
    console.error("Record Mtush installment payment error:", error);
    return res.status(error.statusCode || (error.code === 11000 ? 409 : 500)).json({
      success: false,
      message: error.statusCode
        ? error.message
        : error.code === 11000
          ? "Payment idempotency key already exists"
          : "Failed to record installment payment",
    });
  } finally {
    if (session) await session.endSession();
  }
};

const collectInstallmentOrder = async (req, res) => {
  if (!validOrderId(req.params.orderId)) {
    return res.status(400).json({ success: false, message: "Invalid installment order ID" });
  }
  let session;
  try {
    session = await mongoose.startSession();
    let order;
    await session.withTransaction(async () => {
      order = await MtushInstallmentOrder.findOne({
        _id: req.params.orderId,
        business: req.business._id,
      }).session(session);
      if (!order) throw asError("Installment order not found", 404);
      if (order.status !== "awaiting_collection") {
        throw asError("Order must be fully paid before collection", 409);
      }
      const quantities = new Map();
      for (const entry of order.items) {
        const key = String(entry.item);
        quantities.set(key, (quantities.get(key) || 0) + entry.quantity);
      }
      for (const [itemId, quantity] of quantities) {
        const product = await InventoryItem.findOneAndUpdate(
          {
            _id: itemId,
            business: req.business._id,
            quantityInStock: { $gte: quantity },
            reservedQuantity: { $gte: quantity },
          },
          {
            $inc: { quantityInStock: -quantity, reservedQuantity: -quantity },
          },
          { new: true, session },
        );
        if (!product) throw asError("Reserved stock is no longer available", 409);
        await StockMovement.create(
          [
            {
              business: req.business._id,
              item: product._id,
              type: "stock_out",
              quantity,
              previousQuantity: product.quantityInStock + quantity,
              newQuantity: product.quantityInStock,
              reason: `Mtush installment order ${order._id} collected`,
              recordedBy: req.user._id,
            },
          ],
          { session },
        );
      }
      order.status = "collected";
      order.collectedAt = new Date();
      await order.save({ session });
    });
    return res.status(200).json({
      success: true,
      message: "Installment order collected successfully",
      order,
    });
  } catch (error) {
    console.error("Collect Mtush installment order error:", error);
    return res.status(error.statusCode || 500).json({
      success: false,
      message: error.statusCode ? error.message : "Failed to collect installment order",
    });
  } finally {
    if (session) await session.endSession();
  }
};

const cancelInstallmentOrder = async (req, res) => {
  if (!validOrderId(req.params.orderId)) {
    return res.status(400).json({ success: false, message: "Invalid installment order ID" });
  }
  let session;
  try {
    session = await mongoose.startSession();
    let order;
    await session.withTransaction(async () => {
      order = await MtushInstallmentOrder.findOne({
        _id: req.params.orderId,
        business: req.business._id,
      }).session(session);
      if (!order) throw asError("Installment order not found", 404);
      if (!["pending", "awaiting_collection"].includes(order.status)) {
        throw asError("Only uncollected orders can be cancelled", 409);
      }
      const quantities = new Map();
      for (const entry of order.items) {
        const key = String(entry.item);
        quantities.set(key, (quantities.get(key) || 0) + entry.quantity);
      }
      for (const [itemId, quantity] of quantities) {
        const product = await InventoryItem.findOneAndUpdate(
          {
            _id: itemId,
            business: req.business._id,
            reservedQuantity: { $gte: quantity },
          },
          { $inc: { reservedQuantity: -quantity } },
          { new: true, session },
        );
        if (!product) throw asError("Order reservation could not be released", 409);
      }
      order.status = "cancelled";
      order.cancelledAt = new Date();
      await order.save({ session });
    });
    return res.status(200).json({
      success: true,
      message: "Installment order cancelled and reservations released",
      order,
    });
  } catch (error) {
    console.error("Cancel Mtush installment order error:", error);
    return res.status(error.statusCode || 500).json({
      success: false,
      message: error.statusCode ? error.message : "Failed to cancel installment order",
    });
  } finally {
    if (session) await session.endSession();
  }
};

const getDashboard = async (req, res) => {
  const startValue = req.query.startDate || req.query.from;
  const endValue = req.query.endDate || req.query.to;
  const parseRangeDate = (value, endOfDate = false) => {
    if (typeof value !== "string") return null;
    const isoDate = /^\d{4}-\d{2}-\d{2}$/;
    const isoDateTime =
      /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?(?:Z|[+-]\d{2}:\d{2})?$/;
    if (!isoDate.test(value) && !isoDateTime.test(value)) return null;
    const date = validDate(value);
    if (
      date &&
      isoDate.test(value) &&
      date.toISOString().slice(0, 10) !== value
    ) {
      return null;
    }
    if (date && endOfDate && isoDate.test(value)) {
      date.setUTCHours(23, 59, 59, 999);
    }
    return date;
  };
  const from = startValue ? parseRangeDate(startValue) : null;
  const to = endValue ? parseRangeDate(endValue, true) : null;
  if ((startValue && !from) || (endValue && !to)) {
    return res.status(400).json({ success: false, message: "Invalid date range" });
  }
  if (from && to && from > to) {
    return res.status(400).json({ success: false, message: "from must be before to" });
  }
  const dateFilter = {};
  if (from || to) {
    dateFilter.$gte = from || new Date(0);
    if (to) dateFilter.$lte = to;
  }
  try {
    const business = req.business._id;
    const purchaseFilter = { business };
    const saleFilter = { business, paymentStatus: "paid" };
    const collectedFilter = { business, status: "collected" };
    const activeOrderFilter = { business, status: { $ne: "cancelled" } };
    if (Object.keys(dateFilter).length) {
      purchaseFilter.purchaseDate = dateFilter;
      saleFilter.createdAt = dateFilter;
      collectedFilter.collectedAt = dateFilter;
      activeOrderFilter.createdAt = dateFilter;
    }
    const [
      purchases,
      sales,
      collectedOrders,
      activeOrders,
      allOrders,
      paymentOrders,
      inventory,
    ] = await Promise.all([
        MtushPurchase.find(purchaseFilter).select(
          "purchaseType totalPurchaseCost sellableQuantity",
        ),
        ProductSale.find(saleFilter).select(
          "quantity totalAmount profitPerUnit sellingPrice item createdAt",
        ).populate("item", "costPrice"),
        MtushInstallmentOrder.find(collectedFilter).select(
          "items totalAmount amountPaid",
        ),
        MtushInstallmentOrder.find(activeOrderFilter).select(
          "items totalAmount createdAt",
        ),
        MtushInstallmentOrder.find({
          business,
          status: { $in: ["pending", "awaiting_collection"] },
        }).select("status totalAmount amountPaid"),
        MtushInstallmentOrder.find({ business }).select(
          "payments.amount payments.paidAt",
        ),
        InventoryItem.find({ business, isActive: true }).select(
          "quantityInStock reservedQuantity costPrice reorderLevel name",
        ),
      ]);

    const saleRevenue = sales.reduce((sum, sale) => sum + sale.totalAmount, 0);
    const paymentIsInRange = (payment) => {
      if (!payment.paidAt) return false;
      const paidAt = new Date(payment.paidAt);
      return (
        (!dateFilter.$gte || paidAt >= dateFilter.$gte) &&
        (!dateFilter.$lte || paidAt <= dateFilter.$lte)
      );
    };
    const installmentCash = paymentOrders.reduce(
      (sum, order) =>
        sum +
        order.payments.reduce(
          (paymentSum, payment) =>
            paymentSum + (paymentIsInRange(payment) ? payment.amount : 0),
          0,
        ),
      0,
    );
    const collectedCash = rounded(saleRevenue + installmentCash);
    const saleCogs = sales.reduce(
      (sum, sale) =>
        sum +
        sale.quantity *
          (Number.isFinite(sale.profitPerUnit)
            ? sale.totalAmount / sale.quantity - sale.profitPerUnit
            : sale.item?.costPrice || 0),
      0,
    );
    const orderRevenue = activeOrders.reduce(
      (sum, order) => sum + order.totalAmount,
      0,
    );
    const orderCogs = activeOrders.reduce(
      (sum, order) =>
        sum +
        order.items.reduce(
          (lineSum, item) => lineSum + item.quantity * item.unitCost,
          0,
        ),
      0,
    );
    const collectedOrderRevenue = collectedOrders.reduce(
      (sum, order) => sum + order.totalAmount,
      0,
    );
    const totalPurchaseCost = purchases.reduce(
      (sum, purchase) => sum + purchase.totalPurchaseCost,
      0,
    );
    const pending = allOrders.filter((order) => order.status === "pending");
    const awaitingCollection = allOrders.filter(
      (order) => order.status === "awaiting_collection",
    );
    const outstandingAmount = allOrders.reduce(
      (sum, order) => sum + Math.max(0, order.totalAmount - order.amountPaid),
      0,
    );
    const lowStockItems = inventory
      .filter(
        (item) =>
          item.quantityInStock - (item.reservedQuantity || 0) <= item.reorderLevel,
      )
      .map((item) => ({
        itemId: item._id,
        name: item.name,
        physicalQuantity: item.quantityInStock,
        reservedQuantity: item.reservedQuantity || 0,
        availableQuantity: item.quantityInStock - (item.reservedQuantity || 0),
        reorderLevel: item.reorderLevel,
      }));
    const physicalUnits = inventory.reduce(
      (sum, item) => sum + item.quantityInStock,
      0,
    );
    const reservedUnits = inventory.reduce(
      (sum, item) => sum + (item.reservedQuantity || 0),
      0,
    );
    const inventoryValue = inventory.reduce(
      (sum, item) => sum + item.quantityInStock * item.costPrice,
      0,
    );
    const reservedValue = inventory.reduce(
      (sum, item) => sum + (item.reservedQuantity || 0) * item.costPrice,
      0,
    );
    const revenue = saleRevenue + orderRevenue;
    const cogs = saleCogs + orderCogs;
    const dayMilliseconds = 24 * 60 * 60 * 1000;
    const hasSevenDayRange =
      from &&
      to &&
      Math.abs(to.getTime() - from.getTime() + 1 - 7 * dayMilliseconds) <= 1;
    const profitByDay = hasSevenDayRange ? Array(7).fill(0) : null;
    if (profitByDay) {
      const getDayIndex = (value) =>
        Math.floor((new Date(value).getTime() - from.getTime()) / dayMilliseconds);

      for (const sale of sales) {
        const dayIndex = getDayIndex(sale.createdAt);
        if (dayIndex < 0 || dayIndex >= profitByDay.length) continue;
        const cost =
          sale.quantity *
          (Number.isFinite(sale.profitPerUnit)
            ? sale.totalAmount / sale.quantity - sale.profitPerUnit
            : sale.item?.costPrice || 0);
        profitByDay[dayIndex] += sale.totalAmount - cost;
      }

      for (const order of activeOrders) {
        const dayIndex = getDayIndex(order.createdAt);
        if (dayIndex < 0 || dayIndex >= profitByDay.length) continue;
        const orderCost = order.items.reduce(
          (sum, item) => sum + item.quantity * (item.unitCost || 0),
          0,
        );
        profitByDay[dayIndex] += order.totalAmount - orderCost;
      }
    }

    return res.status(200).json({
      success: true,
      dateRange: { startDate: from || null, endDate: to || null },
      collectedCash,
      metrics: {
        collected: {
          count: sales.length + collectedOrders.length,
          productSalesCount: sales.length,
          installmentOrdersCount: collectedOrders.length,
          cash: collectedCash,
          revenue: rounded(saleRevenue + collectedOrderRevenue),
        },
        revenue: {
          productSales: rounded(saleRevenue),
          installmentOrders: rounded(orderRevenue),
          total: rounded(revenue),
        },
        purchases: {
          count: purchases.length,
          totalCost: rounded(totalPurchaseCost),
          baleCost: rounded(
            purchases
              .filter((purchase) => purchase.purchaseType === "bale")
              .reduce((sum, purchase) => sum + purchase.totalPurchaseCost, 0),
          ),
          individualCost: rounded(
            purchases
              .filter((purchase) => purchase.purchaseType === "individual")
              .reduce((sum, purchase) => sum + purchase.totalPurchaseCost, 0),
          ),
          sellableUnits: purchases.reduce(
            (sum, purchase) => sum + (purchase.sellableQuantity || 0),
            0,
          ),
        },
        cogs: {
          productSales: rounded(saleCogs),
          installmentOrders: rounded(orderCogs),
          total: rounded(cogs),
        },
        profit: {
          productSales: rounded(saleRevenue - saleCogs),
          installmentOrders: rounded(orderRevenue - orderCogs),
          total: rounded(revenue - cogs),
        },
        profitByDay: profitByDay?.map(rounded),
        inventory: {
          productCount: inventory.length,
          physicalUnits,
          availableUnits: physicalUnits - reservedUnits,
          value: rounded(inventoryValue),
        },
        reserved: { units: reservedUnits, value: rounded(reservedValue) },
        lowStock: { count: lowStockItems.length, items: lowStockItems },
        outstanding: {
          orderCount: allOrders.length,
          amount: rounded(outstandingAmount),
        },
        pending: {
          count: pending.length,
          amount: rounded(
            pending.reduce(
              (sum, order) => sum + order.totalAmount - order.amountPaid,
              0,
            ),
          ),
        },
        awaitingCollection: {
          count: awaitingCollection.length,
          amount: rounded(
            awaitingCollection.reduce(
              (sum, order) => sum + order.totalAmount - order.amountPaid,
              0,
            ),
          ),
        },
        collectedOrders: {
          count: collectedOrders.length,
          amount: rounded(collectedOrderRevenue),
        },
      },
    });
  } catch (error) {
    console.error("Get Mtush dashboard error:", error);
    return res.status(500).json({ success: false, message: "Failed to retrieve Mtush dashboard" });
  }
};

module.exports = {
  getPurchases,
  createBalePurchase,
  createIndividualPurchase,
  getInstallmentOrders,
  createInstallmentOrder,
  addInstallmentPayment,
  collectInstallmentOrder,
  cancelInstallmentOrder,
  getDashboard,
};
