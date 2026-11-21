const express = require("express");
const {
  getInstallmentOrders,
  createInstallmentOrder,
  addInstallmentPayment,
  collectInstallmentOrder,
  cancelInstallmentOrder,
  getDashboard,
} = require("../controllers/mtushController");
const { protect } = require("../middleware/authMiddleware");
const { authorizeBusiness } = require("../middleware/businessMiddleware");
const { authorizeRoles } = require("../middleware/roleMiddleware");
const { requireMtushBusiness } = require("../middleware/mtushMiddleware");

const router = express.Router();
const base = [
  protect,
  authorizeBusiness,
  requireMtushBusiness,
];

router.get(
  "/:businessId/mtush/installment-orders",
  ...base,
  authorizeRoles("owner", "manager", "employee"),
  getInstallmentOrders,
);
router.post(
  "/:businessId/mtush/installment-orders",
  ...base,
  authorizeRoles("owner", "manager", "employee"),
  createInstallmentOrder,
);
router.post(
  "/:businessId/mtush/installment-orders/:orderId/payments",
  ...base,
  authorizeRoles("owner", "manager", "employee"),
  addInstallmentPayment,
);
router.post(
  "/:businessId/mtush/installment-orders/:orderId/collect",
  ...base,
  authorizeRoles("owner", "manager", "employee"),
  collectInstallmentOrder,
);
router.post(
  "/:businessId/mtush/installment-orders/:orderId/cancel",
  ...base,
  authorizeRoles("owner", "manager", "employee"),
  cancelInstallmentOrder,
);
router.get(
  "/:businessId/mtush/dashboard",
  ...base,
  authorizeRoles("owner", "manager"),
  getDashboard,
);

module.exports = router;
