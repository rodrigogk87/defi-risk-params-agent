// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/// @title JumpRateModel
/// @author Compound inspired
/// @notice Interest rate model with linear increase until a kink point, then a higher slope after the kink.
/// @dev
/// Borrow rate formula:
/// - Utilization rate: U = borrows / (cash + borrows - reserves)
/// - Before kink:
///     r = baseRate + U * multiplier
/// - After kink:
///     r = baseRate + kink * multiplier + (U - kink) * jumpMultiplier
/// All rates are annual and scaled by 1e18.
contract JumpRateModel is Ownable {
    /// @notice Base annual borrow rate when utilization is 0 (scaled by 1e18)
    uint256 public baseRatePerYear;

    /// @notice Multiplier per year before reaching kink (scaled by 1e18)
    uint256 public multiplierPerYear;

    /// @notice Multiplier per year after reaching kink (scaled by 1e18)
    uint256 public jumpMultiplierPerYear;

    /// @notice Utilization point where jump multiplier starts (scaled by 1e18)
    uint256 public kink;

    /**
     * @param _baseRatePerYear Base rate when utilization is 0
     * @param _multiplierPerYear Slope of rate before kink
     * @param _jumpMultiplierPerYear Slope of rate after kink
     * @param _kink Utilization threshold where jump starts
     */
    constructor(
        uint256 _baseRatePerYear,
        uint256 _multiplierPerYear,
        uint256 _jumpMultiplierPerYear,
        uint256 _kink
    ) Ownable(msg.sender) {
        baseRatePerYear = _baseRatePerYear;
        multiplierPerYear = _multiplierPerYear;
        jumpMultiplierPerYear = _jumpMultiplierPerYear;
        kink = _kink;
    }

    /**
     * @notice Calculates current utilization rate
     * @param cash Available liquidity in the market
     * @param borrows Total borrowed amount
     * @param reserves Reserved funds
     * @return Utilization rate (scaled by 1e18)
     */
    function getUtilizationRate(
        uint256 cash,
        uint256 borrows,
        uint256 reserves
    ) public pure returns (uint256) {
        if (borrows == 0) {
            return 0;
        }
        return (borrows * 1e18) / (cash + borrows - reserves);
    }

    /**
     * @notice Calculates the borrow rate per year given utilization
     * @param cash Available liquidity
     * @param borrows Total borrowed
     * @param reserves Reserved funds
     * @return Borrow rate per year (scaled by 1e18)
     */
    function getBorrowRate(
        uint256 cash,
        uint256 borrows,
        uint256 reserves
    ) external view returns (uint256) {
        uint256 utilization = getUtilizationRate(cash, borrows, reserves);

        if (utilization <= kink) {
            // Before kink: r = base + U * multiplier
            return baseRatePerYear + (utilization * multiplierPerYear) / 1e18;
        } else {
            // After kink: r = base + kink * multiplier + (U - kink) * jumpMultiplier
            uint256 normalRate = baseRatePerYear +
                (kink * multiplierPerYear) /
                1e18;
            uint256 excessUtil = utilization - kink;
            return normalRate + (excessUtil * jumpMultiplierPerYear) / 1e18;
        }
    }

    /**
     * @notice Updates interest rate model parameters
     * @param _baseRatePerYear New base rate
     * @param _multiplierPerYear New multiplier before kink
     * @param _jumpMultiplierPerYear New jump multiplier after kink
     * @param _kink New kink point
     */
    function setParameters(
        uint256 _baseRatePerYear,
        uint256 _multiplierPerYear,
        uint256 _jumpMultiplierPerYear,
        uint256 _kink
    ) external onlyOwner {
        baseRatePerYear = _baseRatePerYear;
        multiplierPerYear = _multiplierPerYear;
        jumpMultiplierPerYear = _jumpMultiplierPerYear;
        kink = _kink;
    }
}
