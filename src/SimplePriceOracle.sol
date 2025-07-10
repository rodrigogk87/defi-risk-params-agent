// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

//TODO: change to chainlink
contract SimplePriceOracle is Ownable {
    mapping(address => uint256) internal _prices;

    address internal _admin;

    constructor() Ownable(msg.sender) {}

    function setPrice(address token, uint256 price) external virtual onlyOwner {
        _prices[token] = price;
    }

    function getUnderlyingPrice(
        address cToken
    ) external view virtual returns (uint256) {
        return _prices[cToken];
    }
}
