const express = require("express");

const {
  createExpense,
  getExpenses,
  updateExpense,
} = require("../controllers/expenseController");

const { protect } = require("../middleware/authMiddleware");
const {
  authorizeBusiness,
} = require("../middleware/businessMiddleware");
const {
  authorizeRoles,
} = require("../middleware/roleMiddleware");

const router = express.Router();

// Record a new expense
router.post(
  "/:businessId/expenses",
  protect,
  authorizeBusiness,
  authorizeRoles("owner", "manager", "employee"),
  createExpense
);

// Retrieve business expenses
router.get(
  "/:businessId/expenses",
  protect,
  authorizeBusiness,
  authorizeRoles("owner", "manager"),
  getExpenses
);

// Update an existing expense
router.patch(
  "/:businessId/expenses/:expenseId",
  protect,
  authorizeBusiness,
  authorizeRoles("owner", "manager"),
  updateExpense
);
module.exports = router;