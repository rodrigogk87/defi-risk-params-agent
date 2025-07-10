// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CErc20.sol";
import "../src/Comptroller.sol";
import "../src/SimplePriceOracle.sol";
import "../src/JumpRateModel.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("MockToken", "MOCK") {
        _mint(msg.sender, 1_000_000 ether);
    }
}

contract CErc20Test is Test {
    MockERC20 public underlying;
    Comptroller public comptroller;
    SimplePriceOracle public priceOracle;
    JumpRateModel public rateModel;
    CErc20 public cToken;

    address public alice = address(1);
    address public bob = address(2);
    address public owner = address(3);

    function setUp() public {
        vm.startPrank(owner);
        // Deploy underlying
        underlying = new MockERC20();

        // Deploy Comptroller and Oracle
        comptroller = new Comptroller();
        priceOracle = new SimplePriceOracle();
        rateModel = new JumpRateModel(0.05e18, 0.15e18, 0.5e18, 0.8e18);

        // Deploy cToken
        cToken = new CErc20(
            address(underlying),
            address(comptroller),
            address(priceOracle),
            address(rateModel)
        );

        // Support market and set collateral factor
        comptroller.supportMarket(address(cToken));
        comptroller._setCollateralFactor(address(cToken), 0.75e18);

        // Set price in oracle
        priceOracle.setPrice(address(cToken), 1e18);

        // Label for easier logs
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");

        // Give tokens to users
        underlying.transfer(alice, 500 ether);
        underlying.transfer(bob, 500 ether);

        // Deal underlying to test contract so it can approve
        underlying.approve(address(cToken), type(uint256).max);
        vm.startPrank(alice);
        underlying.approve(address(cToken), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        underlying.approve(address(cToken), type(uint256).max);
        vm.stopPrank();
    }

    function testMintAndBorrowFlow() public {
        // Set price in oracle
        vm.prank(owner);
        priceOracle.setPrice(address(cToken), 1e18);

        vm.startPrank(alice);
        // Alice mints 100 underlying
        cToken.mint(100 ether);
        assertEq(cToken.balanceOf(alice), 100 ether); // exchange rate 1:1 initially

        // Check liquidity
        (uint256 liquidity, uint256 shortfall) = comptroller
            .getAccountLiquidity(alice);
        assertEq(liquidity, 75 ether); //100*0,75(collateral)*1(ER) - 0(borrow)
        assertEq(shortfall, 0);

        // Alice borrows 50 underlying (should be allowed, 75% collateral factor)
        cToken.borrow(50 ether);

        // Check borrow balance
        uint256 borrowBalance = cToken.getBorrowBalance(alice);
        assertApproxEqAbs(borrowBalance, 50 ether, 1 ether);

        // Check updated liquidity
        (liquidity, shortfall) = comptroller.getAccountLiquidity(alice);
        assertGt(liquidity, 0);
        assertEq(shortfall, 0);

        vm.stopPrank();
    }

    function testRepayAndRedeemFlow() public {
        vm.startPrank(alice);

        cToken.mint(200 ether);
        cToken.borrow(100 ether);

        // Repay part of borrow
        cToken.repayBorrow(50 ether);
        uint256 borrowBalance = cToken.getBorrowBalance(alice);
        assertApproxEqAbs(borrowBalance, 50 ether, 1 ether);

        // Redeem part of supply
        cToken.redeem(50 ether);
        assertLt(cToken.balanceOf(alice), 200 ether);

        vm.stopPrank();
    }

    function testCannotOverBorrow() public {
        vm.startPrank(alice);

        cToken.mint(100 ether);

        // Try borrowing more than allowed
        vm.expectRevert("Borrow not allowed");
        cToken.borrow(90 ether); // 75% collateral factor -> max borrow ~75 ether

        vm.stopPrank();
    }

    function testCannotRedeemAllWhenBorrowed() public {
        vm.startPrank(alice);

        cToken.mint(100 ether);
        cToken.borrow(50 ether);

        // Try redeeming too much collateral while having debt
        vm.expectRevert("Redeem not allowed");
        cToken.redeem(100 ether);

        vm.stopPrank();
    }
}
