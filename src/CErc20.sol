// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Comptroller.sol";
import "./SimplePriceOracle.sol";
import "./JumpRateModel.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CErc20 is ERC20 {
    IERC20 public underlying;
    Comptroller public comptroller;
    SimplePriceOracle public priceOracle;
    JumpRateModel public interestRateModel;

    uint256 public totalBorrows;
    uint256 public totalReserves;
    uint256 public borrowIndex = 1e18;
    uint256 public accrualBlockNumber;

    uint256 public constant initialExchangeRateMantissa = 1e18;

    mapping(address => uint256) public accountBorrows;
    mapping(address => uint256) public accountBorrowIndex;

    constructor(
        address _underlying,
        address _comptroller,
        address _priceOracle,
        address _interestRateModel
    ) ERC20("Compound Token", "cTOKEN") {
        underlying = IERC20(_underlying);
        comptroller = Comptroller(_comptroller);
        priceOracle = SimplePriceOracle(_priceOracle);
        interestRateModel = JumpRateModel(_interestRateModel);

        accrualBlockNumber = block.number;
    }

    /**
     * @notice Accrues interest to borrows and updates borrow index
     */
    function accrueInterest() public {
        uint256 currentBlockNumber = block.number;
        uint256 blockDelta = currentBlockNumber - accrualBlockNumber;

        if (blockDelta == 0) {
            return;
        }

        uint256 borrowRatePerYear = interestRateModel.getBorrowRate(
            underlying.balanceOf(address(this)),
            totalBorrows,
            totalReserves
        );

        uint256 blocksPerYear = 2102400;
        uint256 borrowRatePerBlock = borrowRatePerYear / blocksPerYear;
        uint256 interestFactor = borrowRatePerBlock * blockDelta;

        uint256 interestAccumulated = (interestFactor * totalBorrows) / 1e18;
        totalBorrows += interestAccumulated;

        borrowIndex += (borrowIndex * interestFactor) / 1e18;

        accrualBlockNumber = currentBlockNumber;
    }

    /**
     * @notice Calculates current exchange rate from cTokens to underlying
     */
    function exchangeRateCurrent() public view returns (uint256) {
        uint256 _totalSupply = totalSupply();
        if (_totalSupply == 0) {
            return initialExchangeRateMantissa;
        }

        uint256 cash = underlying.balanceOf(address(this));
        uint256 cashPlusBorrowsMinusReserves = cash +
            totalBorrows -
            totalReserves;

        return (cashPlusBorrowsMinusReserves * 1e18) / _totalSupply;
    }

    function mint(uint256 amount) external {
        require(
            comptroller.mintAllowed(address(this), msg.sender, amount),
            "Mint not allowed"
        );
        require(
            underlying.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

        accrueInterest();

        uint256 exchangeRate = exchangeRateCurrent();
        uint256 cTokensToMint = (amount * 1e18) / exchangeRate;

        _mint(msg.sender, cTokensToMint);
    }

    function redeem(uint256 cTokenAmount) external {
        require(
            comptroller.redeemAllowed(address(this), msg.sender, cTokenAmount),
            "Redeem not allowed"
        );
        require(balanceOf(msg.sender) >= cTokenAmount, "Insufficient balance");

        accrueInterest();

        uint256 exchangeRate = exchangeRateCurrent();
        uint256 underlyingToReturn = (cTokenAmount * exchangeRate) / 1e18;

        _burn(msg.sender, cTokenAmount);
        require(
            underlying.transfer(msg.sender, underlyingToReturn),
            "Transfer failed"
        );
    }

    function borrow(uint256 borrowAmount) external {
        require(
            comptroller.borrowAllowed(address(this), msg.sender, borrowAmount),
            "Borrow not allowed"
        );

        accrueInterest();

        uint256 accountBorrowsPrior = accountBorrows[msg.sender];
        uint256 newBorrowBalance = accountBorrowsPrior + borrowAmount;

        accountBorrows[msg.sender] = newBorrowBalance;
        accountBorrowIndex[msg.sender] = borrowIndex;

        totalBorrows += borrowAmount;

        require(
            underlying.transfer(msg.sender, borrowAmount),
            "Transfer failed"
        );
    }

    function repayBorrow(uint256 repayAmount) external {
        require(
            comptroller.repayBorrowAllowed(
                address(this),
                msg.sender,
                msg.sender,
                repayAmount
            ),
            "Repay not allowed"
        );

        accrueInterest();
        require(
            underlying.transferFrom(msg.sender, address(this), repayAmount),
            "Transfer in failed"
        );

        uint256 accountBorrowsPrior = accountBorrows[msg.sender];
        uint256 newBorrowBalance = accountBorrowsPrior - repayAmount;

        accountBorrows[msg.sender] = newBorrowBalance;
        accountBorrowIndex[msg.sender] = borrowIndex;

        totalBorrows -= repayAmount;
    }

    function getBorrowBalance(
        address borrower
    ) external view returns (uint256) {
        uint256 principal = accountBorrows[borrower];
        uint256 accountIndex = accountBorrowIndex[borrower];

        if (principal == 0) {
            return 0;
        }

        uint256 updatedBalance = (principal * borrowIndex) / accountIndex;
        return updatedBalance;
    }
}
