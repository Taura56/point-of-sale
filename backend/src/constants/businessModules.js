const BUSINESS_MODULES = Object.freeze([
  { key: "cybercafe", name: "Cyber Café", description: "Cyber services and service sales" },
  { key: "phone_repair", name: "Phone Repair", description: "Repair jobs and customer devices" },
  { key: "accessories_shop", name: "Accessories Shop", description: "Accessories stock and sales" },
  { key: "retail_shop", name: "Retail Shop", description: "Retail inventory and sales" },
  { key: "kinyozi", name: "Kinyozi", description: "Barbershop services and sales" },
  { key: "mtush", name: "Mtush", description: "Clothing, shoes, stock and customer balances" },
]);

const BUSINESS_MODULE_KEYS = BUSINESS_MODULES.map((module) => module.key);

const getEnabledBusinessModules = (business) => {
  if (!business) return [];
  if (business.businessType !== "mixed") {
    return BUSINESS_MODULE_KEYS.includes(business.businessType)
      ? [business.businessType]
      : [];
  }

  const configured = Array.isArray(business.enabledModules)
    ? business.enabledModules
    : [];

  // Backward compatibility for existing Mixed accounts created before
  // enabledModules was introduced.
  return configured.length
    ? [...new Set(configured.filter((key) => BUSINESS_MODULE_KEYS.includes(key)))]
    : ["cybercafe", "phone_repair"];
};

module.exports = {
  BUSINESS_MODULES,
  BUSINESS_MODULE_KEYS,
  getEnabledBusinessModules,
};
