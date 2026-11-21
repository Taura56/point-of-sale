const requireMtushBusiness = (req, res, next) => {
  if (!req.business || req.business.businessType !== "mtush") {
    return res.status(403).json({
      success: false,
      message: "This endpoint is only available to Mtush businesses",
    });
  }
  next();
};

module.exports = { requireMtushBusiness };
