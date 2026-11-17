const mongoose = require("mongoose");
const User = require("../models/User");

// Add an existing user to a business
const addMember = async (req, res) => {
  try {
    const { email, role } = req.body;

    // Validate required fields
    if (!email || !role) {
      return res.status(400).json({
        success: false,
        message: "Email and role are required",
      });
    }

    // Only manager and employee roles can be assigned here
    if (!["manager", "employee"].includes(role)) {
      return res.status(400).json({
        success: false,
        message: "Invalid role. Choose manager or employee",
      });
    }

    // Managers can only add employees
    if (req.membership.role === "manager" && role !== "employee") {
      return res.status(403).json({
        success: false,
        message: "Managers can only add employees",
      });
    }

    // Find the registered user
    const member = await User.findOne({
      email: email.trim().toLowerCase(),
    });

    if (!member) {
      return res.status(404).json({
        success: false,
        message: "No registered user found with that email",
      });
    }

    // Do not add suspended accounts
    if (member.status !== "active") {
      return res.status(403).json({
        success: false,
        message: "This user account is suspended",
      });
    }

    // Check whether the user already belongs to this business
    const alreadyMember = member.memberships.some(
      (membership) =>
        membership.business.toString() === req.business._id.toString()
    );

    if (alreadyMember) {
      return res.status(409).json({
        success: false,
        message: "This user is already a member of this business",
      });
    }

    // Add the new business membership
    member.memberships.push({
      business: req.business._id,
      role,
      status: "active",
    });

    await member.save();

    return res.status(201).json({
      success: true,
      message: "Business member added successfully",
      data: {
        fullName: member.fullName,
        email: member.email,
        role,
        business: req.business.name,
      },
    });
  } catch (error) {
    console.error("Add member error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Failed to add business member",
    });
  }
};

const getMembers = async (req, res) => {
  try {
    const members = await User.find({
      memberships: {
        $elemMatch: {
          business: req.business._id,
          status: "active",
        },
      },
    })
      .select("fullName email phone memberships")
      .sort({ fullName: 1 });

    const data = members.map((member) => {
      const membership = member.memberships.find(
        (entry) =>
          entry.business.toString() === req.business._id.toString() &&
          entry.status === "active",
      );
      return {
        id: member._id,
        fullName: member.fullName,
        email: member.email,
        phone: member.phone,
        role: membership.role,
        isOwner: member._id.toString() === req.business.owner.toString(),
      };
    });

    return res.status(200).json({
      success: true,
      count: data.length,
      data,
    });
  } catch (error) {
    console.error("Get business members error:", error.message);
    return res.status(500).json({
      success: false,
      message: "Failed to retrieve business members",
    });
  }
};

const updateMemberRole = async (req, res) => {
  const { role } = req.body || {};
  const { memberId } = req.params;

  if (!mongoose.Types.ObjectId.isValid(memberId)) {
    return res.status(400).json({
      success: false,
      message: "A valid member ID is required",
    });
  }

  if (!["manager", "employee"].includes(role)) {
    return res.status(400).json({
      success: false,
      message: "Role must be manager or employee",
    });
  }

  if (memberId === req.user._id.toString()) {
    return res.status(400).json({
      success: false,
      message: "You cannot change your own business role",
    });
  }

  try {
    const member = await User.findOne({
      _id: memberId,
      memberships: {
        $elemMatch: {
          business: req.business._id,
          status: "active",
        },
      },
    });

    if (!member) {
      return res.status(404).json({
        success: false,
        message: "Active business member not found",
      });
    }

    if (member._id.toString() === req.business.owner.toString()) {
      return res.status(400).json({
        success: false,
        message: "The business owner's role cannot be changed",
      });
    }

    const membership = member.memberships.find(
      (entry) =>
        entry.business.toString() === req.business._id.toString() &&
        entry.status === "active",
    );

    if (
      req.membership.role === "manager" &&
      (membership.role !== "employee" || role !== "employee")
    ) {
      return res.status(403).json({
        success: false,
        message: "Managers can only manage employees",
      });
    }

    membership.role = role;
    await member.save();

    return res.status(200).json({
      success: true,
      message: "Business member role updated successfully",
      data: {
        id: member._id,
        fullName: member.fullName,
        email: member.email,
        role: membership.role,
      },
    });
  } catch (error) {
    console.error("Update business member role error:", error.message);
    return res.status(500).json({
      success: false,
      message: "Failed to update business member role",
    });
  }
};

const removeMember = async (req, res) => {
  const { memberId } = req.params;

  if (!mongoose.Types.ObjectId.isValid(memberId)) {
    return res.status(400).json({
      success: false,
      message: "A valid member ID is required",
    });
  }

  if (memberId === req.user._id.toString()) {
    return res.status(400).json({
      success: false,
      message: "You cannot remove yourself from the business",
    });
  }

  try {
    const member = await User.findOne({
      _id: memberId,
      memberships: {
        $elemMatch: {
          business: req.business._id,
          status: "active",
        },
      },
    });

    if (!member) {
      return res.status(404).json({
        success: false,
        message: "Active business member not found",
      });
    }

    if (member._id.toString() === req.business.owner.toString()) {
      return res.status(400).json({
        success: false,
        message: "The business owner cannot be removed",
      });
    }

    const membershipIndex = member.memberships.findIndex(
      (entry) =>
        entry.business.toString() === req.business._id.toString() &&
        entry.status === "active",
    );
    const membership = member.memberships[membershipIndex];

    if (
      req.membership.role === "manager" &&
      membership.role !== "employee"
    ) {
      return res.status(403).json({
        success: false,
        message: "Managers can only remove employees",
      });
    }

    member.memberships.splice(membershipIndex, 1);
    await member.save();

    return res.status(200).json({
      success: true,
      message: "Business member removed successfully",
    });
  } catch (error) {
    console.error("Remove business member error:", error.message);
    return res.status(500).json({
      success: false,
      message: "Failed to remove business member",
    });
  }
};

module.exports = {
  addMember,
  getMembers,
  updateMemberRole,
  removeMember,
};