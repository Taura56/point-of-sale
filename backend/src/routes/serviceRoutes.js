const express = require("express");

const {
  createService,
  createServiceEntry,
  getServiceEntries,
  getServices,
  updateService,
} = require("../controllers/serviceController");

const { protect } = require("../middleware/authMiddleware");

const { authorizeBusiness } = require("../middleware/businessMiddleware");

const { authorizeRoles } = require("../middleware/roleMiddleware");

const router = express.Router();

// Create a service (owner or manager)
router.post(
  "/:businessId/services",
  protect,
  authorizeBusiness,
  authorizeRoles("owner", "manager"),
  createService
);

// Get active services
router.get(
  "/:businessId/services",
  protect,
  authorizeBusiness,
  getServices
);

// Update a service (owner or manager)
router.patch(
  "/:businessId/services/:serviceId",
  protect,
  authorizeBusiness,
  authorizeRoles("owner", "manager"),
  updateService
);

router.post(
  "/:businessId/service-entries",
  protect,
  authorizeBusiness,
  authorizeRoles("owner", "manager"),
  createServiceEntry
);

router.get(
  "/:businessId/service-entries",
  protect,
  authorizeBusiness,
  authorizeRoles("owner", "manager"),
  getServiceEntries
);

module.exports = router;