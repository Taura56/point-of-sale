const Transaction = require("../models/Transaction");
const Service = require("../models/Service");

// Record a new customer transaction
const createTransaction = async (req, res) => {
  try {
    const {
      serviceId,
      customerName,
      customerPhone,
      quantity,
      externalFee,
      paymentMethod,
      paymentStatus,
      notes,
    } = req.body;

    // Validate required fields
    if (!serviceId) {
      return res.status(400).json({
        success: false,
        message: "Service ID is required",
      });
    }

    const units = Number(quantity ?? 1);
    const outsideFee = Number(externalFee ?? 0);

    if (!Number.isInteger(units) || units < 1) {
      return res.status(400).json({
        success: false,
        message: "Quantity must be a positive whole number",
      });
    }

    if (!Number.isFinite(outsideFee) || outsideFee < 0) {
      return res.status(400).json({
        success: false,
        message: "External fee must be a valid non-negative number",
      });
    }

    // Find service within the authenticated business
    const service = await Service.findOne({
      _id: serviceId,
      business: req.business._id,
      isActive: true,
    });

    if (!service) {
      return res.status(404).json({
        success: false,
        message: "Active service not found in this business",
      });
    }

    // Calculate amounts on the server
    const serviceTotal = service.serviceFee * units;
    const totalAmount = serviceTotal + outsideFee;

    // Create transaction
    const transaction = await Transaction.create({
      business: req.business._id,
      service: service._id,
      customerName: customerName || "Walk-in Customer",
      customerPhone,
      quantity: units,
      serviceFee: service.serviceFee,
      externalFee: outsideFee,
      totalAmount,
      recordedBy: req.user._id,
      paymentMethod,
      paymentStatus,
      notes,
    });

    return res.status(201).json({
      success: true,
      message: "Transaction recorded successfully",
      data: {
        transaction,
        calculation: {
          serviceTotal,
          externalFee: outsideFee,
          totalAmount,
        },
      },
    });
  } catch (error) {
    console.error("Create transaction error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Failed to record transaction",
    });
  }
};

// Retrieve transactions for the selected business
const getTransactions = async (req, res) => {
  try {
    const transactions = await Transaction.find({
      business: req.business._id,
    })
      .populate("service", "name category")
      .populate("recordedBy", "fullName")
      .sort({ createdAt: -1 });

    return res.status(200).json({
      success: true,
      count: transactions.length,
      data: transactions,
    });
  } catch (error) {
    console.error("Get transactions error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Failed to retrieve transactions",
    });
  }
};

module.exports = {
  createTransaction,
  getTransactions,
};