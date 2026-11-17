const RepairJob = require("../models/RepairJob");
const mongoose = require("mongoose");
const User = require("../models/User");

// Register a new repair job
const createRepairJob = async (req, res) => {
  try {
    const {
      repairName,
      price,
      customerName,
      customerPhone,
      deviceType,
      brand,
      model,
      reportedProblem,
      estimatedCost,
      notes,
    } = req.body || {};

    const normalizedRepairName =
      typeof repairName === "string" ? repairName.trim() : "";
    const legacyFields = [
      customerName,
      customerPhone,
      deviceType,
      brand,
      reportedProblem,
    ];
    const hasLegacyDetails = legacyFields.every(
      (field) => typeof field === "string" && field.trim(),
    );
    const priceValue = price ?? estimatedCost;
    const hasPrice =
      priceValue !== undefined &&
      priceValue !== null &&
      !(typeof priceValue === "string" && !priceValue.trim());

    if (!normalizedRepairName && !hasLegacyDetails) {
      return res.status(400).json({
        success: false,
        message: "Please provide a repair name",
      });
    }

    if (normalizedRepairName && !hasPrice) {
      return res.status(400).json({
        success: false,
        message: "Repair price is required",
      });
    }

    const estimate = priceValue === undefined || priceValue === null
      ? 0
      : Number(priceValue);

    if (!Number.isFinite(estimate) || estimate < 0) {
      return res.status(400).json({
        success: false,
        message: "Repair price must be a valid non-negative number",
      });
    }

    // Create repair job under the authenticated business
    const repairJob = await RepairJob.create({
      business: req.business._id,
      ...(normalizedRepairName ? { repairName: normalizedRepairName } : {}),
      customerName,
      customerPhone,
      deviceType,
      brand,
      model,
      reportedProblem,
      estimatedCost: estimate,
      receivedBy: req.user._id,
      notes,
    });

    return res.status(201).json({
      success: true,
      message: "Repair job registered successfully",
      data: repairJob,
    });
  } catch (error) {
    console.error("Create repair job error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Failed to register repair job",
    });
  }
};

// Get all repair jobs for a business
const getRepairJobs = async (req, res) => {
  try {
    const jobs = await RepairJob.find({
      business: req.business._id,
    })
      .populate("receivedBy", "fullName")
      .populate("assignedTo", "fullName")
      .sort({ createdAt: -1 });

    return res.status(200).json({
      success: true,
      count: jobs.length,
      data: jobs,
    });
  } catch (error) {
    console.error("Get repair jobs error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Failed to retrieve repair jobs",
    });
  }
};

// Update repair job status and financial details
const updateRepairJob = async (req, res) => {
  try {
    const { status, diagnosis, repairCost, amountPaid, assignedTo, notes } =
      req.body;

    const job = await RepairJob.findOne({
      _id: req.params.jobId,
      business: req.business._id,
    });

    if (!job) {
      return res.status(404).json({
        success: false,
        message: "Repair job not found",
      });
    }
    if (job.status === "cancelled") {
      return res.status(400).json({
        success: false,
        message: "Cannot update a cancelled repair job",
      });
    }

    // Validate repair status
    const allowedStatuses = [
      "received",
      "diagnosing",
      "waiting_for_approval",
      "waiting_for_parts",
      "in_progress",
      "completed",
      "collected",
      "cancelled",
    ];

    if (status !== undefined) {
      if (!allowedStatuses.includes(status)) {
        return res.status(400).json({
          success: false,
          message: "Invalid repair status",
        });
      }

      job.status = status;
    }

    if (diagnosis !== undefined) job.diagnosis = diagnosis;
    if (notes !== undefined) job.notes = notes;

    if (repairCost !== undefined) {
      const cost = Number(repairCost);

      if (!Number.isFinite(cost) || cost < 0) {
        return res.status(400).json({
          success: false,
          message: "Repair cost must be a valid non-negative number",
        });
      }

      job.repairCost = cost;
    }

    if (amountPaid !== undefined) {
      const paid = Number(amountPaid);

      if (!Number.isFinite(paid) || paid < 0) {
        return res.status(400).json({
          success: false,
          message: "Amount paid must be a valid non-negative number",
        });
      }

      job.amountPaid = paid;
    }

    // Prevent recording payments above the repair cost
    if (job.amountPaid > job.repairCost) {
      return res.status(400).json({
        success: false,
        message: "Amount paid cannot exceed the repair cost",
      });
    }

  if (assignedTo !== undefined) {
    // Allow removing the current technician
    if (assignedTo === null || assignedTo === "") {
      job.assignedTo = null;
    } else {
      // Validate MongoDB user ID
      if (!mongoose.Types.ObjectId.isValid(assignedTo)) {
        return res.status(400).json({
          success: false,
          message: "Invalid technician ID",
        });
      }

      // Find an active user who belongs to this business
      const technician = await User.findOne({
        _id: assignedTo,
        status: "active",
        memberships: {
          $elemMatch: {
            business: req.business._id,
            status: "active",
          },
        },
      });

      if (!technician) {
        return res.status(404).json({
          success: false,
          message: "Technician is not an active member of this business",
        });
      }

      job.assignedTo = technician._id;
    }
  }

    await job.save();

const balance = job.repairCost - job.amountPaid;

  let paymentStatus = "unpaid";

  if (job.amountPaid > 0 && job.amountPaid < job.repairCost) {
    paymentStatus = "partially_paid";
  } else if (job.amountPaid >= job.repairCost && job.repairCost > 0) {
    paymentStatus = "fully_paid";
  }

  return res.status(200).json({
    success: true,
    message: "Repair job updated successfully",
    job: {
      ...job.toObject(),
      balance,
      paymentStatus,
    },
  });
  } catch (error) {
    console.error("Update repair job error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Failed to update repair job",
    });
  }
};

module.exports = {
  createRepairJob,
  getRepairJobs,
  updateRepairJob,
};