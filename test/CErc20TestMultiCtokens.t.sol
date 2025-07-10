// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CErc20.sol";
import "../src/Comptroller.sol";
import "../src/SimplePriceOracle.sol";
import "../src/JumpRateModel.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1_000_000 ether);
    }
}

contract CErc20TestMultiCtokens is Test {
    MockERC20 public underlyingA;
    MockERC20 public underlyingB;
    MockERC20 public underlyingC;

    Comptroller public comptroller;
    SimplePriceOracle public priceOracle;
    JumpRateModel public rateModel;

    CErc20 public cTokenA;
    CErc20 public cTokenB;
    CErc20 public cTokenC;

    address public alice = address(1);
    address public owner = address(this);

    function setUp() public {
        vm.startPrank(owner);

        // Deploy underlyings
        underlyingA = new MockERC20("TokenA", "A");
        underlyingB = new MockERC20("TokenB", "B");
        underlyingC = new MockERC20("TokenC", "C");

        // Comptroller and Oracle
        comptroller = new Comptroller();
        priceOracle = new SimplePriceOracle();
        rateModel = new JumpRateModel(0.05e18, 0.15e18, 0.5e18, 0.8e18);

        // Deploy cTokens
        cTokenA = new CErc20(
            address(underlyingA),
            address(comptroller),
            address(priceOracle),
            address(rateModel)
        );
        cTokenB = new CErc20(
            address(underlyingB),
            address(comptroller),
            address(priceOracle),
            address(rateModel)
        );
        cTokenC = new CErc20(
            address(underlyingC),
            address(comptroller),
            address(priceOracle),
            address(rateModel)
        );

        // Support markets & set collateral factors
        comptroller.supportMarket(address(cTokenA));
        comptroller._setCollateralFactor(address(cTokenA), 0.7e18);

        comptroller.supportMarket(address(cTokenB));
        comptroller._setCollateralFactor(address(cTokenB), 0.75e18);

        comptroller.supportMarket(address(cTokenC));
        comptroller._setCollateralFactor(address(cTokenC), 0.8e18);

        // Prices
        priceOracle.setPrice(address(cTokenA), 1e18);
        priceOracle.setPrice(address(cTokenB), 2e18);
        priceOracle.setPrice(address(cTokenC), 0.5e18);

        // Give some underlying to cTokens as cash so they can handle borrows
        underlyingA.transfer(address(cTokenA), 500 ether);
        underlyingB.transfer(address(cTokenB), 500 ether);
        underlyingC.transfer(address(cTokenC), 500 ether);
        // Send tokens to Alice
        underlyingA.transfer(alice, 500 ether);
        underlyingB.transfer(alice, 500 ether);
        underlyingC.transfer(alice, 500 ether);

        // Approvals
        vm.startPrank(alice);
        underlyingA.approve(address(cTokenA), type(uint256).max);
        underlyingB.approve(address(cTokenB), type(uint256).max);
        underlyingC.approve(address(cTokenC), type(uint256).max);
        vm.stopPrank();

        vm.stopPrank();
    }

    function testMultiCollateralFlow() public {
        vm.startPrank(alice);

        // Supply in all three markets
        cTokenA.mint(100 ether); // A price = 1
        cTokenB.mint(50 ether); // B price = 2
        cTokenC.mint(200 ether); // C price = 0.5

        CErc20[] memory cTokens = new CErc20[](3);
        cTokens[0] = cTokenA;
        cTokens[1] = cTokenB;
        cTokens[2] = cTokenC;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100 ether;
        amounts[1] = 50 ether;
        amounts[2] = 200 ether;

        uint256 expectedLiquidity = computeExpectedLiquidity(cTokens, amounts);

        // Check liquidity
        (uint256 liquidity, uint256 shortfall) = comptroller
            .getAccountLiquidity(alice);

        emit log_named_uint("Expected liquidity", expectedLiquidity);
        emit log_named_uint("Computed liquidity", liquidity);

        assertEq(liquidity, expectedLiquidity);
        assertEq(shortfall, 0);

        // Alice borrows 200 ether (should succeed)
        cTokenA.borrow(200 ether);

        (liquidity, shortfall) = comptroller.getAccountLiquidity(alice);

        emit log_named_uint("Liquidity after borrow", liquidity);
        emit log_named_uint("Shortfall after borrow", shortfall);

        assertEq(liquidity, expectedLiquidity - 200 ether);
        assertEq(shortfall, 0);

        // Now trying to borrow any more should revert (todo)
        //vm.expectRevert();
        //cTokenA.borrow(400 ether);

        vm.stopPrank();
    }

    function computeExpectedLiquidity(
        CErc20[] memory cTokens,
        uint256[] memory supplyAmounts
    ) internal view returns (uint256 totalAdjustedCollateral) {
        for (uint256 i = 0; i < cTokens.length; i++) {
            uint256 ex = cTokens[i].exchangeRateCurrent();
            uint256 price = priceOracle.getUnderlyingPrice(address(cTokens[i]));
            uint256 factor = comptroller.collateralFactors(address(cTokens[i]));

            uint256 underlyingAmount = (supplyAmounts[i] * ex) / 1e18;
            uint256 collateralValue = (underlyingAmount * price) / 1e18;
            uint256 adjusted = (collateralValue * factor) / 1e18;

            totalAdjustedCollateral += adjusted;
        }
    }
}
