const express = require("express");

const {
  createInventoryItem,
  getInventoryItems,
  getLowStockItems,
  updateInventoryItem,
  deleteInventoryItem,
} = require("../controllers/inventoryController");

const { protect } = require("../middleware/authMiddleware");
const { authorizeBusiness } = require("../middleware/businessMiddleware");
const { authorizeRoles } = require("../middleware/roleMiddleware");

const router = express.Router();

// Register a new inventory item
router.post(
  "/:businessId/inventory",
  protect,
  authorizeBusiness,
  authorizeRoles("owner", "manager", "employee"),
  createInventoryItem
);

// Retrieve inventory items
router.get(
  "/:businessId/inventory",
  protect,
  authorizeBusiness,
  getInventoryItems
);

// Retrieve products that need restocking
router.get(
  "/:businessId/inventory/low-stock",
  protect,
  authorizeBusiness,
  authorizeRoles("owner", "manager"),
  getLowStockItems
);

// Update inventory item details
router.patch(
  "/:businessId/inventory/:itemId",
  protect,
  authorizeBusiness,
  authorizeRoles("owner", "manager"),
  updateInventoryItem
);

// Remove an inventory item without deleting its sales or stock history
router.delete(
  "/:businessId/inventory/:itemId",
  protect,
  authorizeBusiness,
  authorizeRoles("owner", "manager"),
  deleteInventoryItem
);

module.exports = router;