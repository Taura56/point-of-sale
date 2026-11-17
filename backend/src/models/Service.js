const mongoose = require("mongoose");

const serviceSchema = new mongoose.Schema(
  {
    // Business that owns this service
    business: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Business",
      required: true,
      index: true,
    },

    // Service name displayed in the application
    name: {
      type: String,
      required: true,
      trim: true,
    },

    // Service category
    category: {
      type: String,
      enum: [
        "printing",
        "photocopy",
        "scanning",
        "typing",
        "online_application",
        "laminating",
        "binding",
        "other",
      ],
      default: "other",
    },

    description: {
      type: String,
      trim: true,
    },

    // Amount charged by the business
    serviceFee: {
      type: Number,
      required: true,
      min: 0,
    },

    // Whether the service is currently offered
    isActive: {
      type: Boolean,
      default: true,
    },

    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
  },
  {
    timestamps: true,
  }
);

// Avoid duplicate service names within the same business
serviceSchema.index(
  { business: 1, name: 1 },
  { unique: true }
);

module.exports = mongoose.model("Service", serviceSchema);