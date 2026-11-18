const Transaction = require("../models/Transaction");
const ProductSale = require("../models/ProductSale");
const ServiceEntry = require("../models/ServiceEntry");
const Expense = require("../models/Expense");
const InventoryItem = require("../models/InventoryItem");
const RepairJob = require("../models/RepairJob");

const dashboardDisplayKeys = [
  "dailyTotalMoney",
  "lowStockItems",
  "weeklyTithe",
  "weeklyOperatingProfit",
  "dailyExpenses",
];

const getDashboardDisplays = async (req, res) => {
  const preference = req.user.dashboardDisplayPreferences?.find(
    (entry) => entry.business.toString() === req.business._id.toString()
  );
  const savedDisplays = preference ? preference.displays : ["dailyTotalMoney"];
  const displays = savedDisplays.filter((display) =>
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
    let dayStart;
    let dayEnd;
    let weekBoundaries;

    if (req.query.dayStart !== undefined || req.query.dayEnd !== undefined) {
      if (
        typeof req.query.dayStart !== "string" ||
        typeof req.query.dayEnd !== "string"
      ) {
        return res.status(400).json({
          success: false,
          message: "A valid single-day date range is required",
        });
      }

      dayStart = new Date(req.query.dayStart);
      dayEnd = new Date(req.query.dayEnd);
      const rangeLength = dayEnd.getTime() - dayStart.getTime();
      if (
        !Number.isFinite(dayStart.getTime()) ||
        !Number.isFinite(dayEnd.getTime()) ||
        rangeLength <= 0 ||
        rangeLength > 26 * 60 * 60 * 1000
      ) {
        return res.status(400).json({
          success: false,
          message: "A valid single-day date range is required",
        });
      }
    } else {
      const today = new Date();
      dayStart = new Date(today.getFullYear(), today.getMonth(), today.getDate());
      dayEnd = new Date(dayStart);
      dayEnd.setDate(dayEnd.getDate() + 1);
    }

    if (req.query.weekBoundaries !== undefined) {
      let rawBoundaries;
      try {
        rawBoundaries = JSON.parse(req.query.weekBoundaries);
      } catch {
        return res.status(400).json({
          success: false,
          message: "A valid Sunday-to-Saturday date range is required",
        });
      }

      if (
        !Array.isArray(rawBoundaries) ||
        rawBoundaries.length !== 8 ||
        rawBoundaries.some((boundary) => typeof boundary !== "string")
      ) {
        return res.status(400).json({
          success: false,
          message: "A valid Sunday-to-Saturday date range is required",
        });
      }

      weekBoundaries = rawBoundaries.map((boundary) => new Date(boundary));
    } else {
      const weekStart = new Date(dayStart);
      weekStart.setHours(0, 0, 0, 0);
      weekStart.setDate(weekStart.getDate() - weekStart.getDay());
      weekBoundaries = Array.from({ length: 8 }, (_, index) => {
        const boundary = new Date(weekStart);
        boundary.setDate(boundary.getDate() + index);
        return boundary;
      });
    }

    if (
      weekBoundaries.some(
        (boundary, index) =>
          !Number.isFinite(boundary.getTime()) ||
          (index > 0 &&
            (boundary <= weekBoundaries[index - 1] ||
              boundary.getTime() - weekBoundaries[index - 1].getTime() >
                26 * 60 * 60 * 1000))
      )
    ) {
      return res.status(400).json({
        success: false,
        message: "A valid Sunday-to-Saturday date range is required",
      });
    }

    const todayBucketIndex = weekBoundaries.findIndex(
      (boundary, index) =>
        index < 7 &&
        boundary.getTime() === dayStart.getTime() &&
        weekBoundaries[index + 1].getTime() === dayEnd.getTime()
    );
    if (todayBucketIndex < 0) {
      return res.status(400).json({
        success: false,
        message: "The selected day must be within the requested week",
      });
    }

    const weekDateFilter = {
      business: businessId,
      createdAt: {
        $gte: weekBoundaries[0],
        $lt: weekBoundaries[7],
      },
    };
    const bucketByDay = (amount) => [
      { $match: weekDateFilter },
      {
        $bucket: {
          groupBy: "$createdAt",
          boundaries: weekBoundaries,
          output: { total: { $sum: amount } },
        },
      },
    ];

    const [weeklyIncomeGroups, weeklyExpenseGroups] = await Promise.all([
      Promise.all([
        Transaction.aggregate([
          { $match: { ...weekDateFilter, paymentStatus: "paid" } },
          {
            $bucket: {
              groupBy: "$createdAt",
              boundaries: weekBoundaries,
              output: { total: { $sum: "$totalAmount" } },
            },
          },
        ]),
        ProductSale.aggregate([
          { $match: { ...weekDateFilter, paymentStatus: "paid" } },
          {
            $bucket: {
              groupBy: "$createdAt",
              boundaries: weekBoundaries,
              output: {
                total: {
                  $sum: {
                    $multiply: [
                      { $ifNull: ["$profitPerUnit", 0] },
                      "$quantity",
                    ],
                  },
                },
              },
            },
          },
        ]),
        ServiceEntry.aggregate(bucketByDay("$totalPrice")),
        RepairJob.aggregate(bucketByDay("$amountPaid")),
      ]),
      Expense.aggregate([
        {
          $match: {
            business: businessId,
            expenseDate: {
              $gte: weekBoundaries[0],
              $lt: weekBoundaries[7],
            },
          },
        },
        {
          $bucket: {
            groupBy: "$expenseDate",
            boundaries: weekBoundaries,
            output: { total: { $sum: "$amount" } },
          },
        },
      ]),
    ]);

    const weeklyMoneyByDay = Array(7).fill(0);
    for (const sourceGroups of weeklyIncomeGroups) {
      for (const group of sourceGroups) {
        const dayIndex = weekBoundaries.findIndex(
          (boundary, index) =>
            index < 7 && boundary.getTime() === new Date(group._id).getTime()
        );
        if (dayIndex >= 0) {
          weeklyMoneyByDay[dayIndex] += group.total || 0;
        }
      }
    }
    const weeklyTotalMoney = weeklyMoneyByDay.reduce(
      (total, amount) => total + amount,
      0
    );
    const dailyTotalMoney = weeklyMoneyByDay[todayBucketIndex];
    const weeklyTithe = weeklyTotalMoney * 0.1;
    const dailyExpenses =
      weeklyExpenseGroups.find(
        (group) =>
          new Date(group._id).getTime() ===
          weekBoundaries[todayBucketIndex].getTime()
      )?.total || 0;

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
        dailyTotalMoney,
        weeklyMoneyByDay,
        weeklyTotalMoney,
        weeklyTithe,
        dailyExpenses,
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