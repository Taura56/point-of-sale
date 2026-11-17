const express = require("express");
const { protect } = require("../middleware/authMiddleware");

const {
  register,
  login,
  updateMyProfile,
  changeMyPassword,
} = require("../controllers/authController");

const router = express.Router();

// Register a new business account
router.post("/register", register);

// Login an existing user
router.post("/login", login);

// Get the currently authenticated user
router.get("/me", protect, (req, res) => {
  res.status(200).json({
    success: true,
    data: {
      id: req.user._id,
      fullName: req.user.fullName,
      email: req.user.email,
      phone: req.user.phone,
      memberships: req.user.memberships,
    },
  });
});

router.patch("/me", protect, updateMyProfile);
router.patch("/me/password", protect, changeMyPassword);

module.exports = router;