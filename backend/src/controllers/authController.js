const mongoose = require("mongoose");
const User = require("../models/User");
const Business = require("../models/Business");
const { BUSINESS_MODULE_KEYS } = require("../constants/businessModules");
const jwt = require("jsonwebtoken");

// Register a new user and business
const register = async (req, res) => {
  const { fullName, email, phone, password, businessName, businessType } =
    req.body;
  const requestedModules = req.body?.enabledModules;

  // Validate required fields
  if (
    !fullName ||
    !email ||
    !password ||
    !businessName ||
    !businessType
  ) {
    return res.status(400).json({
      success: false,
      message: "Please provide all required registration fields",
    });
  }

  if (
    !["cybercafe", "phone_repair", "accessories_shop", "retail_shop", "kinyozi", "mtush", "mixed"].includes(businessType)
  ) {
    return res.status(400).json({
      success: false,
      message: "Please choose one of the supported business types.",
    });
  }

  if (
    requestedModules !== undefined &&
    (!Array.isArray(requestedModules) ||
      requestedModules.some(
        (module) =>
          typeof module !== "string" || !BUSINESS_MODULE_KEYS.includes(module)
      ))
  ) {
    return res.status(400).json({
      success: false,
      message: "Please choose valid business modules.",
    });
  }

  if (password.length < 8) {
    return res.status(400).json({
      success: false,
      message: "Password must contain at least 8 characters",
    });
  }

  const session = await mongoose.startSession();

  try {
    let createdUser;
    let createdBusiness;

    await session.withTransaction(async () => {
      // Create user account
      const user = new User({
        fullName,
        email,
        phone,
        password,
      });

      await user.save({ session });

      // Create business
      const business = new Business({
        name: businessName,
        businessType,
        ...(businessType === "mixed" && requestedModules !== undefined
          ? { enabledModules: [...new Set(requestedModules)] }
          : {}),
        owner: user._id,
      });

      await business.save({ session });

      // Assign owner membership
      user.memberships.push({
        business: business._id,
        role: "owner",
        status: "active",
      });

      await user.save({ session });

      createdUser = user;
      createdBusiness = business;
    });

    return res.status(201).json({
      success: true,
      message: "Business account registered successfully",
      data: {
        user: {
          id: createdUser._id,
          fullName: createdUser.fullName,
          email: createdUser.email,
        },
        business: {
          id: createdBusiness._id,
          name: createdBusiness.name,
          businessType: createdBusiness.businessType,
        },
      },
    });
  } catch (error) {
    console.error("Registration error:", error.message);

    if (error.code === 11000) {
      return res.status(409).json({
        success: false,
        message: "An account with this email already exists",
      });
    }

    return res.status(500).json({
      success: false,
      message: "Registration failed",
    });
  } finally {
    await session.endSession();
  }
};

// Login an existing user
const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: "Email and password are required",
      });
    }

    // Find user and explicitly include the password hash
    const user = await User.findOne({
      email: email.toLowerCase().trim(),
    }).select("+password");

    if (!user) {
      return res.status(401).json({
        success: false,
        message: "Invalid email or password",
      });
    }

    // Compare submitted password with stored hash
    const passwordIsCorrect = await user.comparePassword(password);

    if (!passwordIsCorrect) {
      return res.status(401).json({
        success: false,
        message: "Invalid email or password",
      });
    }

    if (user.status !== "active") {
      return res.status(403).json({
        success: false,
        message: "Your account is suspended",
      });
    }

    // Generate authentication token
  const token = jwt.sign(
    {
      userId: user._id,
    },
    process.env.JWT_SECRET,
    {
      expiresIn: process.env.JWT_EXPIRES_IN || "1d",
    }
  );

    return res.status(200).json({
    success: true,
    message: "Login successful",
    data: {
      token,
      user: {
        id: user._id,
        fullName: user.fullName,
        email: user.email,
        memberships: user.memberships,
      },
    },
  });
  } catch (error) {
    console.error("Login error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Login failed",
    });
  }
};

const updateMyProfile = async (req, res) => {
  const { fullName, email, phone } = req.body || {};

  if (typeof fullName !== "string" || !fullName.trim()) {
    return res.status(400).json({
      success: false,
      message: "Full name cannot be empty",
    });
  }

  const normalizedEmail =
    typeof email === "string" ? email.trim().toLowerCase() : "";
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizedEmail)) {
    return res.status(400).json({
      success: false,
      message: "Enter a valid email address",
    });
  }

  if (phone !== undefined && phone !== null && typeof phone !== "string") {
    return res.status(400).json({
      success: false,
      message: "Invalid phone number",
    });
  }

  try {
    const user = await User.findById(req.user._id);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User account not found",
      });
    }

    user.fullName = fullName.trim();
    user.email = normalizedEmail;
    user.phone = phone?.trim() ?? "";
    await user.save();

    return res.status(200).json({
      success: true,
      message: "Account profile updated successfully",
      data: {
        id: user._id,
        fullName: user.fullName,
        email: user.email,
        phone: user.phone,
      },
    });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(409).json({
        success: false,
        message: "An account with this email already exists",
      });
    }

    console.error("Update account profile error:", error.message);
    return res.status(500).json({
      success: false,
      message: "Failed to update account profile",
    });
  }
};

const changeMyPassword = async (req, res) => {
  const { currentPassword, newPassword } = req.body || {};

  if (
    typeof currentPassword !== "string" ||
    !currentPassword ||
    typeof newPassword !== "string" ||
    !newPassword
  ) {
    return res.status(400).json({
      success: false,
      message: "Current and new passwords are required",
    });
  }

  if (newPassword.length < 8) {
    return res.status(400).json({
      success: false,
      message: "New password must contain at least 8 characters",
    });
  }

  if (currentPassword === newPassword) {
    return res.status(400).json({
      success: false,
      message: "New password must be different from the current password",
    });
  }

  try {
    const user = await User.findById(req.user._id).select("+password");
    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User account not found",
      });
    }

    if (!(await user.comparePassword(currentPassword))) {
      return res.status(400).json({
        success: false,
        message: "Current password is incorrect",
      });
    }

    user.password = newPassword;
    await user.save();

    return res.status(200).json({
      success: true,
      message: "Password changed successfully",
    });
  } catch (error) {
    console.error("Change password error:", error.message);
    return res.status(500).json({
      success: false,
      message: "Failed to change password",
    });
  }
};

module.exports = {
  register,
  login,
  updateMyProfile,
  changeMyPassword,
};