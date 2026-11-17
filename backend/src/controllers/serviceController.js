const mongoose = require("mongoose");
const Service = require("../models/Service");
const ServiceEntry = require("../models/ServiceEntry");

// Create a new business service
const createService = async (req, res) => {
  try {
    const { name, category, description, serviceFee } = req.body;

    // Validate required fields
    if (!name || serviceFee === undefined) {
      return res.status(400).json({
        success: false,
        message: "Service name and service fee are required",
      });
    }

    // Validate the service fee
    const fee = Number(serviceFee);

    if (!Number.isFinite(fee) || fee < 0) {
      return res.status(400).json({
        success: false,
        message: "Service fee must be a valid non-negative number",
      });
    }

    // Create the service under the authenticated business
    const service = await Service.create({
      business: req.business._id,
      name,
      category,
      description,
      serviceFee: fee,
      createdBy: req.user._id,
    });

    return res.status(201).json({
      success: true,
      message: "Service created successfully",
      data: service,
    });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(409).json({
        success: false,
        message: "A service with this name already exists",
      });
    }

    console.error("Create service error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Failed to create service",
    });
  }
};

// Get services belonging to the selected business
const getServices = async (req, res) => {
  try {
    const services = await Service.find({
      business: req.business._id,
      isActive: true,
    }).sort({ name: 1 });

    return res.status(200).json({
      success: true,
      count: services.length,
      data: services,
    });
  } catch (error) {
    console.error("Get services error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Failed to retrieve services",
    });
  }
};

// Update the price of a service belonging to the selected business
const updateService = async (req, res) => {
  try {
    const { serviceFee } = req.body;

    if (serviceFee === undefined) {
      return res.status(400).json({
        success: false,
        message: "Service fee is required",
      });
    }

    const fee = Number(serviceFee);

    if (!Number.isFinite(fee) || fee < 0) {
      return res.status(400).json({
        success: false,
        message: "Service fee must be a valid non-negative number",
      });
    }

    const service = await Service.findOne({
      _id: req.params.serviceId,
      business: req.business._id,
    });

    if (!service) {
      return res.status(404).json({
        success: false,
        message: "Service not found",
      });
    }

    service.serviceFee = fee;
    await service.save();

    return res.status(200).json({
      success: true,
      message: "Service updated successfully",
      data: service,
    });
  } catch (error) {
    console.error("Update service error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Failed to update service",
    });
  }
};

const createServiceEntry = async (req, res) => {
  const { serviceId, name, serviceFee, quantity, totalPrice } = req.body || {};
  const normalizedName = typeof name === "string" ? name.trim() : "";
  const unitPrice = Number(serviceFee);
  const units = Number(quantity);
  const submittedTotal = Number(totalPrice);

  if (
    !normalizedName ||
    !Number.isFinite(unitPrice) ||
    unitPrice < 0 ||
    !Number.isSafeInteger(units) ||
    units < 1 ||
    !Number.isFinite(submittedTotal) ||
    submittedTotal < 0
  ) {
    return res.status(400).json({
      success: false,
      message: "Enter a valid service name, unit price, quantity and total price",
    });
  }

  const calculatedTotal = unitPrice * units;
  if (Math.abs(submittedTotal - calculatedTotal) > 0.01) {
    return res.status(400).json({
      success: false,
      message: "Total price must equal unit price multiplied by quantity",
    });
  }

  if (serviceId && !mongoose.Types.ObjectId.isValid(serviceId)) {
    return res.status(400).json({
      success: false,
      message: "A valid service ID is required",
    });
  }

  let session;
  try {
    session = await mongoose.startSession();

    let service;
    let entry;
    await session.withTransaction(async () => {
      if (serviceId) {
        service = await Service.findOne({
          _id: serviceId,
          business: req.business._id,
          isActive: true,
        }).session(session);

        if (!service) {
          const error = new Error("Active service not found");
          error.statusCode = 404;
          throw error;
        }

        if (service.name.trim().toLowerCase() !== normalizedName.toLowerCase()) {
          const error = new Error("Service name does not match the selected service");
          error.statusCode = 400;
          throw error;
        }
      } else {
        const escapedName = normalizedName.replace(
          /[.*+?^${}()|[\]\\]/g,
          "\\$&",
        );
        service = await Service.findOne({
          business: req.business._id,
          isActive: true,
          name: { $regex: `^${escapedName}$`, $options: "i" },
        }).session(session);
      }

      if (service) {
        service.serviceFee = unitPrice;
        await service.save({ session });
      } else {
        [service] = await Service.create(
          [
            {
              business: req.business._id,
              name: normalizedName,
              serviceFee: unitPrice,
              createdBy: req.user._id,
            },
          ],
          { session },
        );
      }

      [entry] = await ServiceEntry.create(
        [
          {
            business: req.business._id,
            service: service._id,
            serviceName: service.name,
            unitPrice,
            quantity: units,
            totalPrice: calculatedTotal,
            recordedBy: req.user._id,
          },
        ],
        { session },
      );
    });

    return res.status(201).json({
      success: true,
      message: "Service details saved successfully",
      data: { service, entry },
    });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(409).json({
        success: false,
        message: "A service with this name already exists",
      });
    }

    console.error("Create service entry error:", error);

    return res.status(error.statusCode || 500).json({
      success: false,
      message: error.statusCode
        ? error.message
        : "Failed to save service details",
    });
  } finally {
    if (session) {
      await session.endSession();
    }
  }
};

const getServiceEntries = async (req, res) => {
  try {
    const entries = await ServiceEntry.find({
      business: req.business._id,
    }).sort({ createdAt: -1 });

    return res.status(200).json({
      success: true,
      count: entries.length,
      entries,
    });
  } catch (error) {
    console.error("Get service entries error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to retrieve service details",
    });
  }
};

module.exports = {
  createService,
  createServiceEntry,
  getServiceEntries,
  getServices,
  updateService,
};