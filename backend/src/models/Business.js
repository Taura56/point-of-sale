const mongoose = require("mongoose");

const businessSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
      trim: true,
    },

    businessType: {
      type: String,
      enum: [
        "cybercafe",
        "phone_repair",
        "accessories_shop",
        "retail_shop",
        "kinyozi",
        "mtush",
        "mixed",
        // Kept temporarily so existing legacy records remain readable.
        // It will no longer be offered during registration or in Settings.
        "other",
      ],
      default: "mixed",
      required: true,
    },

    // Mixed businesses can enable multiple modules. Standalone businesses
    // always resolve to their single businessType module.
    enabledModules: {
      type: [String],
      default: function () {
        if (this.businessType === "mixed") {
          return ["cybercafe", "phone_repair"];
        }
        return this.businessType && this.businessType !== "other"
          ? [this.businessType]
          : [];
      },
    },

    owner: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    phone: {
      type: String,
      trim: true,
    },

    email: {
      type: String,
      trim: true,
      lowercase: true,
    },

    location: {
      type: String,
      trim: true,
    },

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

const Business = mongoose.model("Business", businessSchema);

module.exports = Business;
