// forge script script/Deploy.s.sol --fork-url http://localhost:8545 --broadcast
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/Comptroller.sol";
import "../src/SimplePriceOracle.sol";
import "../src/JumpRateModel.sol";
import "../src/CErc20.sol";
import "./MockERC20.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_ANVIL");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Oracle
        SimplePriceOracle oracle = new SimplePriceOracle();
        console.log("Oracle deployed at:", address(oracle));

        // Deploy Comptroller
        Comptroller comptroller = new Comptroller();
        console.log("Comptroller deployed at:", address(comptroller));

        // Deploy JumpRateModel
        JumpRateModel rateModel = new JumpRateModel(
            0.05e18, // baseRatePerYear
            0.15e18, // multiplierPerYear
            0.5e18, // jumpMultiplierPerYear
            0.8e18 // kink
        );
        console.log("JumpRateModel deployed at:", address(rateModel));

        // Deploy Mock ERC20 as underlying
        MockERC20 underlying = new MockERC20("Mock DAI", "mDAI");
        console.log("Underlying token deployed at:", address(underlying));

        // Deploy CErc20
        CErc20 cToken = new CErc20(
            address(underlying),
            address(comptroller),
            address(oracle),
            address(rateModel)
        );
        console.log("CErc20 token deployed at:", address(cToken));

        // Configure
        comptroller.supportMarket(address(cToken));
        comptroller._setCollateralFactor(address(cToken), 0.75e18);
        oracle.setPrice(address(cToken), 1e18); // Set price to 1

        vm.stopBroadcast();
    }
}
