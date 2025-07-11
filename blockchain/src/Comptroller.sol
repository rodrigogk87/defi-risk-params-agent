// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./CErc20.sol";
import "./SimplePriceOracle.sol";

contract Comptroller is Ownable {
    mapping(address => bool) public markets;
    mapping(address => uint256) public collateralFactors;
    address[] public allMarkets;

    constructor() Ownable(msg.sender) {}

    function supportMarket(address cToken) external onlyOwner {
        require(!markets[cToken], "Already supported");
        markets[cToken] = true;
        allMarkets.push(cToken);
    }

    function _setCollateralFactor(
        address cToken,
        uint256 newFactorMantissa
    ) external onlyOwner {
        require(markets[cToken], "Market not supported");
        require(newFactorMantissa <= 0.9e18, "Too high");
        collateralFactors[cToken] = newFactorMantissa;
    }

    function mintAllowed(
        address cToken,
        address,
        uint256
    ) external view returns (bool) {
        require(markets[cToken], "Market not listed");
        return true;
    }

    function redeemAllowed(
        address cToken,
        address redeemer,
        uint256 redeemAmount
    ) external view returns (bool) {
        require(markets[cToken], "Market not listed");

        uint256 exchangeRate = CErc20(cToken).exchangeRateCurrent();
        uint256 underlyingAmount = (redeemAmount * exchangeRate) / 1e18;

        return _hasSufficientLiquidity(redeemer, cToken, underlyingAmount);
    }

    function borrowAllowed(
        address cToken,
        address borrower,
        uint256 borrowAmount
    ) external view returns (bool) {
        require(markets[cToken], "Market not listed");
        return _hasSufficientLiquidity(borrower, cToken, borrowAmount);
    }

    function repayBorrowAllowed(
        address,
        address,
        address,
        uint256
    ) external pure returns (bool) {
        return true;
    }

    function transferAllowed(
        address cToken,
        address,
        address,
        uint256
    ) external view returns (bool) {
        require(markets[cToken], "Market not listed");
        return true;
    }

    struct Vars {
        uint256 totalCollateralValue;
        uint256 totalBorrowValue;
        uint256 collateralFactor;
        uint256 cTokenBalance;
        uint256 exchangeRate;
        uint256 underlyingAmount;
        uint256 price;
        uint256 collateralValue;
        uint256 adjustedCollateral;
        uint256 borrowBalance;
        uint256 borrowValue;
    }

    function getAccountLiquidity(
        address account
    ) public view returns (uint256 liquidity, uint256 shortfall) {
        Vars memory vars;

        for (uint256 i = 0; i < allMarkets.length; i++) {
            address cToken = allMarkets[i];
            vars.collateralFactor = collateralFactors[cToken];
            if (vars.collateralFactor == 0) continue;

            vars.cTokenBalance = IERC20(cToken).balanceOf(account);
            vars.exchangeRate = CErc20(cToken).exchangeRateCurrent();
            vars.underlyingAmount =
                (vars.cTokenBalance * vars.exchangeRate) /
                1e18;

            vars.price = SimplePriceOracle(CErc20(cToken).priceOracle())
                .getUnderlyingPrice(cToken);
            vars.collateralValue = (vars.underlyingAmount * vars.price) / 1e18;
            vars.adjustedCollateral =
                (vars.collateralValue * vars.collateralFactor) /
                1e18;

            vars.totalCollateralValue += vars.adjustedCollateral;

            vars.borrowBalance = CErc20(cToken).getBorrowBalance(account);
            vars.borrowValue = (vars.borrowBalance * vars.price) / 1e18;
            vars.totalBorrowValue += vars.borrowValue;
        }

        if (vars.totalCollateralValue > vars.totalBorrowValue) {
            liquidity = vars.totalCollateralValue - vars.totalBorrowValue;
            shortfall = 0;
        } else {
            liquidity = 0;
            shortfall = vars.totalBorrowValue - vars.totalCollateralValue;
        }
    }

    function _hasSufficientLiquidity(
        address user,
        address cToken,
        uint256 amountUnderlying
    ) internal view returns (bool) {
        (uint256 liquidity, uint256 shortfall) = getAccountLiquidity(user);

        uint256 price = SimplePriceOracle(CErc20(cToken).priceOracle())
            .getUnderlyingPrice(cToken);
        uint256 value = (amountUnderlying * price) / 1e18;

        if (shortfall > 0 || liquidity < value) {
            return false;
        }
        return true;
    }
}
