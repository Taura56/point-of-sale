const express = require("express");

const {
  recordStockMovement,
  getStockMovements,
} = require("../controllers/stockMovementController");


const { protect } = require("../middleware/authMiddleware");
const {
  authorizeBusiness,
} = require("../middleware/businessMiddleware");
const {
  authorizeRoles,
} = require("../middleware/roleMiddleware");

const router = express.Router();

// Record stock received or stock issued
router.post(
  "/:businessId/stock-movements",
  protect,
  authorizeBusiness,
  authorizeRoles("owner", "manager", "employee"),
  recordStockMovement
);
// Retrieve stock movement history
router.get(
  "/:businessId/stock-movements",
  protect,
  authorizeBusiness,
  authorizeRoles("owner", "manager"),
  getStockMovements
);

module.exports = router;