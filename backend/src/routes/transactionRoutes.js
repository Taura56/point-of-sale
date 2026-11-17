const express = require("express");

const {
  createTransaction,
  getTransactions,
} = require("../controllers/transactionController");

const { protect } = require("../middleware/authMiddleware");
const { authorizeBusiness } = require("../middleware/businessMiddleware");
const { authorizeRoles } = require("../middleware/roleMiddleware");

const router = express.Router();

// All business members can record sales
router.post(
  "/:businessId/transactions",
  protect,
  authorizeBusiness,
  authorizeRoles("owner", "manager", "employee"),
  createTransaction
);

// Only owners and managers can view transaction records
router.get(
  "/:businessId/transactions",
  protect,
  authorizeBusiness,
  authorizeRoles("owner", "manager"),
  getTransactions
);

module.exports = router;