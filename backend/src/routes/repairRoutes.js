const express = require("express");

const {
  createRepairJob,
  getRepairJobs,
  updateRepairJob,
} = require("../controllers/repairController");

const { protect } = require("../middleware/authMiddleware");
const { authorizeBusiness } = require("../middleware/businessMiddleware");
const { authorizeRoles } = require("../middleware/roleMiddleware");

const router = express.Router();

// Register a new repair job
router.post(
  "/:businessId/repairs",
  protect,
  authorizeBusiness,
  authorizeRoles("owner", "manager", "employee"),
  createRepairJob
);

// Retrieve repair jobs
router.get(
  "/:businessId/repairs",
  protect,
  authorizeBusiness,
  authorizeRoles("owner", "manager", "employee"),
  getRepairJobs
);

// Update repair progress and payment details
router.patch(
  "/:businessId/repairs/:jobId",
  protect,
  authorizeBusiness,
  authorizeRoles("owner", "manager", "employee"),
  updateRepairJob
);

module.exports = router;