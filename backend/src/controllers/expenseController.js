const Expense = require("../models/Expense");

// Record a new business expense
const createExpense = async (req, res) => {
  try {
    const {
      title,
      category,
      amount,
      paymentMethod,
      description,
      expenseDate,
    } = req.body;

    if (!title || amount === undefined) {
      return res.status(400).json({
        success: false,
        message: "Expense title and amount are required",
      });
    }

    const expenseAmount = Number(amount);

    if (!Number.isFinite(expenseAmount) || expenseAmount <= 0) {
      return res.status(400).json({
        success: false,
        message: "Expense amount must be greater than zero",
      });
    }

    const parsedDate = expenseDate
      ? new Date(expenseDate)
      : new Date();

    if (Number.isNaN(parsedDate.getTime())) {
      return res.status(400).json({
        success: false,
        message: "Invalid expense date",
      });
    }

    const expense = await Expense.create({
      business: req.business._id,
      title,
      category,
      amount: expenseAmount,
      paymentMethod,
      description,
      expenseDate: parsedDate,
      recordedBy: req.user._id,
    });

    return res.status(201).json({
      success: true,
      message: "Expense recorded successfully",
      expense,
    });
  } catch (error) {
    console.error("Create expense error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to record expense",
    });
  }
};

// Retrieve expenses for the current business
const getExpenses = async (req, res) => {
  try {
    const expenses = await Expense.find({
      business: req.business._id,
    })
      .populate("recordedBy", "fullName")
      .sort({ expenseDate: -1 });

    return res.status(200).json({
      success: true,
      count: expenses.length,
      expenses,
    });
  } catch (error) {
    console.error("Get expenses error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to retrieve expenses",
    });
  }
};

// Update an existing business expense
const updateExpense = async (req, res) => {
  try {
    const {
      title,
      category,
      amount,
      paymentMethod,
      description,
      expenseDate,
    } = req.body;

    const expense = await Expense.findOne({
      _id: req.params.expenseId,
      business: req.business._id,
    });

    if (!expense) {
      return res.status(404).json({
        success: false,
        message: "Expense not found",
      });
    }

    if (title !== undefined) {
      if (typeof title !== "string" || !title.trim()) {
        return res.status(400).json({
          success: false,
          message: "Expense title cannot be empty",
        });
      }
      expense.title = title;
    }

    if (amount !== undefined) {
      const expenseAmount = Number(amount);

      if (!Number.isFinite(expenseAmount) || expenseAmount <= 0) {
        return res.status(400).json({
          success: false,
          message: "Expense amount must be greater than zero",
        });
      }

      expense.amount = expenseAmount;
    }

    if (category !== undefined) expense.category = category;
    if (paymentMethod !== undefined) expense.paymentMethod = paymentMethod;
    if (description !== undefined) expense.description = description;

    if (expenseDate !== undefined) {
      const parsedDate = new Date(expenseDate);

      if (Number.isNaN(parsedDate.getTime())) {
        return res.status(400).json({
          success: false,
          message: "Invalid expense date",
        });
      }

      expense.expenseDate = parsedDate;
    }

    await expense.save();

    return res.status(200).json({
      success: true,
      message: "Expense updated successfully",
      expense,
    });
  } catch (error) {
    console.error("Update expense error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to update expense",
    });
  }
};

module.exports = {
  createExpense,
  getExpenses,
  updateExpense,
};
