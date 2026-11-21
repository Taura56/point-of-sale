// Load environment variables
require("dotenv").config();

const connectDatabase = require("./config/database");
const authRoutes = require("./routes/authRoutes");
const businessRoutes = require("./routes/businessRoutes");
const serviceRoutes = require("./routes/serviceRoutes");
const transactionRoutes = require("./routes/transactionRoutes");
const repairRoutes = require("./routes/repairRoutes");
const inventoryRoutes = require("./routes/inventoryRoutes");
const stockMovementRoutes = require("./routes/stockMovementRoutes");
const productSaleRoutes = require("./routes/productSaleRoutes");
const expenseRoutes = require("./routes/expenseRoutes");
const dashboardRoutes = require("./routes/dashboardRoutes");
const mtushRoutes = require("./routes/mtushRoutes");
const cors = require("cors");


// Import Express
const express = require("express");

// Create Express application
const app = express();

// Middleware to read JSON request bodies
app.use(express.json());
app.use(cors());
app.use("/api/auth", authRoutes);
app.use("/api/businesses", businessRoutes);
app.use("/api/businesses", serviceRoutes);
app.use("/api/businesses", transactionRoutes);
app.use("/api/businesses", repairRoutes);
app.use("/api/businesses", inventoryRoutes);
app.use("/api/businesses", stockMovementRoutes);
app.use("/api/businesses", productSaleRoutes);
app.use("/api/businesses", expenseRoutes);
app.use("/api/businesses", dashboardRoutes);
app.use("/api/businesses", mtushRoutes);


// Basic API welcome route
app.get("/", (req, res) => {
  res.status(200).json({
    success: true,
    message: "Business Manager API is running",
  });
});

// Health-check route
app.get("/api/health", (req, res) => {
  res.status(200).json({
    success: true,
    status: "healthy",
  });
});


// Start server after connecting to MongoDB
const PORT = process.env.PORT || 3000;

const startServer = async () => {
  await connectDatabase();

  app.listen(PORT, () => {
    console.log(`Business Manager API running on port ${PORT}`);
  });
};

startServer();