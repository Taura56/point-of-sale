const Business = require("../models/Business");
const { getEnabledBusinessModules } = require("../constants/businessModules");

const getBusinessSettings = async (req, res) => {
  const business = req.business;

  return res.status(200).json({
    success: true,
    data: {
      business: {
        id: business._id,
        name: business.name,
        businessType: business.businessType,
        phone: business.phone,
        email: business.email,
        location: business.location,
      },
      role: req.membership.role,
    },
  });
};

const updateBusinessSettings = async (req, res) => {
  const body = req.body || {};
  const { name, businessType, phone, email, location } = body;

  if (name !== undefined && (typeof name !== "string" || !name.trim())) {
    return res.status(400).json({
      success: false,
      message: "Business name cannot be empty",
    });
  }

  if (
    businessType !== undefined &&
    !Business.schema.path("businessType").enumValues.includes(businessType)
  ) {
    return res.status(400).json({
      success: false,
      message: "Invalid business type",
    });
  }

  for (const [field, value] of [
    ["phone", phone],
    ["email", email],
    ["location", location],
  ]) {
    if (value !== undefined && value !== null && typeof value !== "string") {
      return res.status(400).json({
        success: false,
        message: `Invalid business ${field}`,
      });
    }
  }

  if (email?.trim() && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) {
    return res.status(400).json({
      success: false,
      message: "Enter a valid business email address",
    });
  }

  try {
    const business = req.business;
    if (name !== undefined) business.name = name.trim();
    if (businessType !== undefined) business.businessType = businessType;
    if (phone !== undefined) business.phone = phone?.trim() ?? "";
    if (email !== undefined) business.email = email?.trim().toLowerCase() ?? "";
    if (location !== undefined) business.location = location?.trim() ?? "";

    await business.save();

    return res.status(200).json({
      success: true,
      message: "Business settings updated successfully",
      data: {
        business: {
          id: business._id,
          name: business.name,
          businessType: business.businessType,
          phone: business.phone,
          email: business.email,
          location: business.location,
        },
      },
    });
  } catch (error) {
    console.error("Update business settings error:", error.message);
    return res.status(500).json({
      success: false,
      message: "Failed to update business settings",
    });
  }
};

module.exports = {
  getBusinessSettings,
  updateBusinessSettings,
};
