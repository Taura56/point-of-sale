const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");

const userSchema = new mongoose.Schema(
  {
    fullName: {
      type: String,
      required: true,
      trim: true,
    },

    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
    },

    phone: {
      type: String,
      trim: true,
    },

    password: {
      type: String,
      required: true,
      minlength: 8,
      select: false,
    },

    memberships: [
    {
        business: {
        type: mongoose.Schema.Types.ObjectId,
        ref: "Business",
        required: true,
        },

        role: {
        type: String,
        enum: ["owner", "manager", "employee"],
        required: true,
        },

        status: {
        type: String,
        enum: ["active", "pending", "suspended"],
        default: "active",
        },
    },
    ],

    dashboardDisplayPreferences: [
      {
        business: {
          type: mongoose.Schema.Types.ObjectId,
          ref: "Business",
          required: true,
        },
        displays: [
          {
            type: String,
          },
        ],
      },
    ],

    status: {
      type: String,
      enum: ["active", "suspended"],
      default: "active",
    },
  },
  {
    timestamps: true,
  }
);

// Hash password before saving a new or changed password
userSchema.pre("save", async function () {
  if (!this.isModified("password")) return;

  this.password = await bcrypt.hash(this.password, 12);
});

// Compare entered password with stored password hash
userSchema.methods.comparePassword = async function (enteredPassword) {
  return bcrypt.compare(enteredPassword, this.password);
};

const User = mongoose.model("User", userSchema);

module.exports = User;