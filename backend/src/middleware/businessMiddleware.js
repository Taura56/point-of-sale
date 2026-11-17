const mongoose = require("mongoose");
const Business = require("../models/Business");

// Check whether the logged-in user belongs to the requested business
const authorizeBusiness = async (req, res, next) => {
  try {
    const { businessId } = req.params;

    // Validate business ID
    if (!mongoose.Types.ObjectId.isValid(businessId)) {
      return res.status(400).json({
        success: false,
        message: "Invalid business ID",
      });
    }

    // Find the business
    const business = await Business.findById(businessId);

    if (!business || business.status !== "active") {
      return res.status(404).json({
        success: false,
        message: "Business not found or inactive",
      });
    }

    // Check the user's membership
    const membership = req.user.memberships.find(
      (item) =>
        item.business.toString() === businessId &&
        item.status === "active"
    );

    if (!membership) {
      return res.status(403).json({
        success: false,
        message: "You do not have access to this business",
      });
    }

    // Attach business and membership information
    req.business = business;
    req.membership = membership;

    next();
  } catch (error) {
    console.error("Business authorization error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Business authorization failed",
    });
  }
};

module.exports = { authorizeBusiness };