const express = require("express");

const {
  createProductSale,
  getProductSales,
} = require("../controllers/productSaleController");

const { protect } = require("../middleware/authMiddleware");
const { authorizeBusiness } = require("../middleware/businessMiddleware");
const { authorizeRoles } = require("../middleware/roleMiddleware");

const router = express.Router();

router.post(
  "/:businessId/product-sales",
  protect,
  authorizeBusiness,
  authorizeRoles("owner", "manager", "employee"),
  createProductSale
);

router.get(
  "/:businessId/product-sales",
  protect,
  authorizeBusiness,
  authorizeRoles("owner", "manager"),
  getProductSales
);

module.exports = router;
