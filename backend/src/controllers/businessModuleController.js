const {
  BUSINESS_MODULES,
  BUSINESS_MODULE_KEYS,
  getEnabledBusinessModules,
} = require("../constants/businessModules");

const getBusinessModules = async (req, res) => {
  const enabledModules = getEnabledBusinessModules(req.business);

  return res.status(200).json({
    success: true,
    data: {
      businessType: req.business.businessType,
      modules: BUSINESS_MODULES.map((module) => ({
        ...module,
        enabled: enabledModules.includes(module.key),
      })),
      enabledModules,
      canManage: req.membership.role === "owner",
    },
  });
};

const updateBusinessModules = async (req, res) => {
  if (req.business.businessType !== "mixed") {
    return res.status(409).json({
      success: false,
      message: "Modules can only be added or removed for Mixed Business accounts.",
    });
  }

  const { enabledModules } = req.body || {};
  if (
    !Array.isArray(enabledModules) ||
    enabledModules.some(
      (key) => typeof key !== "string" || !BUSINESS_MODULE_KEYS.includes(key)
    )
  ) {
    return res.status(400).json({
      success: false,
      message: "Choose valid business modules.",
    });
  }

  const uniqueModules = [...new Set(enabledModules)];
  req.business.enabledModules = uniqueModules;

  try {
    await req.business.save();

    return res.status(200).json({
      success: true,
      message: "Business modules updated successfully.",
      data: {
        enabledModules: getEnabledBusinessModules(req.business),
      },
    });
  } catch (error) {
    console.error("Update business modules error:", error.message);
    return res.status(500).json({
      success: false,
      message: "Failed to update business modules.",
    });
  }
};

module.exports = {
  getBusinessModules,
  updateBusinessModules,
};
