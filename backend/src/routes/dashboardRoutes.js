const express = require("express");

const {
  getDashboardStats,
  getDashboardDisplays,
  updateDashboardDisplays,
} = require("../controllers/dashboardController");

const { protect } = require("../middleware/authMiddleware");
const {
  authorizeBusiness,
} = require("../middleware/businessMiddleware");
const {
  authorizeRoles,
} = require("../middleware/roleMiddleware");

const router = express.Router();

router.get(
  "/:businessId/dashboard/displays",
  protect,
  authorizeBusiness,
  getDashboardDisplays
);

router.patch(
  "/:businessId/dashboard/displays",
  protect,
  authorizeBusiness,
  updateDashboardDisplays
);

// Retrieve business dashboard statistics
router.get(
  "/:businessId/dashboard",
  protect,
  authorizeBusiness,
  authorizeRoles("owner", "manager"),
  getDashboardStats
);

module.exports = router;