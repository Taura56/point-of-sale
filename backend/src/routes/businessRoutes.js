const express = require("express");

const { protect } = require("../middleware/authMiddleware");
const {
  authorizeBusiness,
} = require("../middleware/businessMiddleware");
const { authorizeRoles } = require("../middleware/roleMiddleware");
const {
  addMember,
  getMembers,
  updateMemberRole,
  removeMember,
} = require("../controllers/memberController");
const {
  getBusinessSettings,
  updateBusinessSettings,
} = require("../controllers/settingsController");


const router = express.Router();

// Test access to a specific business
router.get("/:businessId/access-check", protect, authorizeBusiness, (req, res) => {
  res.status(200).json({
    success: true,
    message: "Business access granted",
    data: {
      business: req.business.name,
      businessId: req.business._id,
      role: req.membership.role,
    },
  });
});

// Only owners can access this route
router.get(
  "/:businessId/owner-only",
  protect,
  authorizeBusiness,
  authorizeRoles("owner"),
  (req, res) => {
    res.status(200).json({
      success: true,
      message: "Owner access granted",
      role: req.membership.role,
    });
  }
);

router.get(
  "/:businessId/settings",
  protect,
  authorizeBusiness,
  getBusinessSettings
);

router.patch(
  "/:businessId/settings",
  protect,
  authorizeBusiness,
  authorizeRoles("owner"),
  updateBusinessSettings
);

// Add a manager or employee to a business
router.post(
  "/:businessId/members",
  protect,
  authorizeBusiness,
  authorizeRoles("owner", "manager"),
  addMember
);

router.get(
  "/:businessId/members",
  protect,
  authorizeBusiness,
  authorizeRoles("owner", "manager"),
  getMembers
);

router.patch(
  "/:businessId/members/:memberId",
  protect,
  authorizeBusiness,
  authorizeRoles("owner", "manager"),
  updateMemberRole
);

router.delete(
  "/:businessId/members/:memberId",
  protect,
  authorizeBusiness,
  authorizeRoles("owner", "manager"),
  removeMember
);

module.exports = router;