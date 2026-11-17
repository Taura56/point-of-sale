const Transaction = require("../models/Transaction");
const Expense = require("../models/Expense");
const InventoryItem = require("../models/InventoryItem");
const RepairJob = require("../models/RepairJob");

const dashboardDisplayKeys = [];

const getDashboardDisplays = async (req, res) => {
  const preference = req.user.dashboardDisplayPreferences?.find(
    (entry) => entry.business.toString() === req.business._id.toString()
  );
  const displays = (preference?.displays ?? []).filter((display) =>
    dashboardDisplayKeys.includes(display)
  );

  return res.status(200).json({
    success: true,
    data: {
      displays,
    },
  });
};

const updateDashboardDisplays = async (req, res) => {
  const { displays } = req.body || {};

  if (
    !Array.isArray(displays) ||
    displays.some(
      (display) =>
        typeof display !== "string" ||
        !dashboardDisplayKeys.includes(display)
    )
  ) {
    return res.status(400).json({
      success: false,
      message: "Choose valid dashboard displays",
    });
  }

  const uniqueDisplays = [...new Set(displays)];
  if (!req.user.dashboardDisplayPreferences) {
    req.user.dashboardDisplayPreferences = [];
  }
  const preference = req.user.dashboardDisplayPreferences.find(
    (entry) => entry.business.toString() === req.business._id.toString()
  );

  if (preference) {
    preference.displays = uniqueDisplays;
  } else {
    req.user.dashboardDisplayPreferences.push({
      business: req.business._id,
      displays: uniqueDisplays,
    });
  }

  try {
    await req.user.save();

    return res.status(200).json({
      success: true,
      message: "Dashboard displays updated successfully",
      data: {
        displays: uniqueDisplays,
      },
    });
  } catch (error) {
    console.error("Update dashboard displays error:", error.message);
    return res.status(500).json({
      success: false,
      message: "Failed to update dashboard displays",
    });
  }
};

const getDashboardStats = async (req, res) => {
  try {
    const businessId = req.business._id;

    // Calculate paid sales revenue
    const sales = await Transaction.aggregate([
      {
        $match: {
          business: businessId,
          paymentStatus: "paid",
        },
      },
      {
        $group: {
          _id: null,
          totalServiceRevenue: {
            $sum: {
              $multiply: ["$serviceFee", "$quantity"],
            },
          },
          totalExternalFees: {
            $sum: "$externalFee",
          },
          totalCollected: {
            $sum: "$totalAmount",
          },
          transactionCount: {
            $sum: 1,
          },
        },
      },
    ]);

    const salesStats = sales[0] || {
      totalServiceRevenue: 0,
      totalExternalFees: 0,
      totalCollected: 0,
      transactionCount: 0,
    };

    // Calculate total business expenses
    const expenseStats = await Expense.aggregate([
      {
        $match: {
          business: businessId,
        },
      },
      {
        $group: {
          _id: null,
          totalExpenses: {
            $sum: "$amount",
          },
        },
      },
    ]);

    const totalExpenses = expenseStats[0]?.totalExpenses || 0;

    // Count inventory products
    const totalProducts = await InventoryItem.countDocuments({
      business: businessId,
      isActive: true,
    });

    // Count products requiring restocking
    const lowStockItems = await InventoryItem.countDocuments({
      business: businessId,
      isActive: true,
      $expr: {
        $lte: ["$quantityInStock", "$reorderLevel"],
      },
    });

    // Count repair jobs by status
    const activeRepairs = await RepairJob.countDocuments({
      business: businessId,
      status: {
        $nin: ["completed", "collected", "cancelled"],
      },
    });

    const completedRepairs = await RepairJob.countDocuments({
      business: businessId,
      status: "completed",
    });

    return res.status(200).json({
      success: true,
      dashboard: {
        totalServiceRevenue: salesStats.totalServiceRevenue,
        totalExternalFees: salesStats.totalExternalFees,
        totalCollected: salesStats.totalCollected,
        transactionCount: salesStats.transactionCount,
        totalExpenses,
        estimatedOperatingProfit:
          salesStats.totalServiceRevenue - totalExpenses,
        totalProducts,
        lowStockItems,
        activeRepairs,
        completedRepairs,
      },
    });
  } catch (error) {
    console.error("Dashboard statistics error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to retrieve dashboard statistics",
    });
  }
};

module.exports = {
  getDashboardStats,
  getDashboardDisplays,
  updateDashboardDisplays,
};