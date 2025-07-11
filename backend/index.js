require("dotenv").config();
const { ethers } = require("ethers");
const fs = require("fs");
const express = require("express");

const app = express();
app.use(express.json()); // Para parsear JSON en requests POST

const PORT = process.env.PORT || 3001;

// Leer addresses.json
const addresses = JSON.parse(fs.readFileSync("../blockchain/script/addresses.json", "utf-8"));

const comptrollerAddress = addresses.find(a => a.contract === "Comptroller")?.address;
const cTokenAddress = addresses.find(a => a.contract === "CErc20")?.address;
const oracleAddress = addresses.find(a => a.contract === "SimplePriceOracle")?.address;

if (!comptrollerAddress || !cTokenAddress || !oracleAddress) {
    console.error("❌ No se encontraron las direcciones en addresses.json");
    process.exit(1);
}

console.log("✅ Addresses loaded from JSON:");
console.log("Comptroller:", comptrollerAddress);
console.log("cToken:", cTokenAddress);
console.log("Oracle:", oracleAddress);

// RPC y wallet
const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

// ABIs
const comptrollerArtifacts = require("../blockchain/out/Comptroller.sol/Comptroller.json");
const cTokenArtifacts = require("../blockchain/out/CErc20.sol/CErc20.json");
const oracleArtifacts = require("../blockchain/out/SimplePriceOracle.sol/SimplePriceOracle.json");

// Instanciar contratos
const comptroller = new ethers.Contract(comptrollerAddress, comptrollerArtifacts.abi, wallet);
const cToken = new ethers.Contract(cTokenAddress, cTokenArtifacts.abi, wallet);
const oracle = new ethers.Contract(oracleAddress, oracleArtifacts.abi, wallet);


// === GET status endpoint ===
app.get("/api/status", async (req, res) => {
    try {
        const price = await oracle.getUnderlyingPrice(cTokenAddress);
        const factor = await comptroller.collateralFactors(cTokenAddress);
        const borrows = await cToken.totalBorrows();

        res.json({
            collateral_factor: parseFloat(ethers.formatUnits(factor, 18)),
            total_borrows: parseFloat(ethers.formatEther(borrows)),
            token_price: parseFloat(ethers.formatUnits(price, 18))
        });
    } catch (err) {
        console.error("❌ Error fetching on-chain data:", err);
        res.status(500).json({ error: "Error fetching on-chain data" });
    }
});

// === POST update price endpoint ===
app.post("/api/update-price", async (req, res) => {
    const { newPrice } = req.body;
    if (!newPrice) {
        return res.status(400).json({ error: "Missing newPrice in body" });
    }

    try {
        const tx = await oracle.setPrice(cTokenAddress, ethers.parseUnits(newPrice.toString(), 18));
        await tx.wait();
        console.log("✅ Price updated on-chain:", newPrice);
        res.json({ success: true, newPrice });
    } catch (err) {
        console.error("❌ Error updating price:", err);
        res.status(500).json({ error: "Failed to update price" });
    }
});

// === POST update collateral factor endpoint ===
app.post("/api/update-collateral", async (req, res) => {
    const { newFactor } = req.body;
    if (!newFactor) {
        return res.status(400).json({ error: "Missing newFactor in body" });
    }

    try {
        const tx = await comptroller._setCollateralFactor(cTokenAddress, ethers.parseUnits(newFactor.toString(), 18));
        await tx.wait();
        console.log("✅ Collateral factor updated on-chain:", newFactor);
        res.json({ success: true, newFactor });
    } catch (err) {
        console.error("❌ Error updating collateral factor:", err);
        res.status(500).json({ error: "Failed to update collateral factor" });
    }
});

// Start
app.listen(PORT, () => {
    console.log(`🚀 Backend running on http://localhost:${PORT}`);
});
