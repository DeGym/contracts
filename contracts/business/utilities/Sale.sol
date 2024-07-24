// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Governor.sol";

contract Sale is Ownable {
    Governor public governor;
    uint256 public preSeedPrice;
    uint256 public privateSalePrice;
    uint256 public publicSalePrice;
    uint256 public preSeedStart;
    uint256 public preSeedEnd;
    uint256 public privateSaleStart;
    uint256 public privateSaleEnd;
    uint256 public publicSaleStart;
    uint256 public publicSaleEnd;

    enum SalePhase {
        PreSeed,
        PrivateSale,
        PublicSale
    }
    SalePhase public currentPhase;

    constructor(Governor _governor) {
        governor = _governor;
    }

    function setSaleDetails(
        uint256 _preSeedPrice,
        uint256 _privateSalePrice,
        uint256 _publicSalePrice,
        uint256 _preSeedStart,
        uint256 _preSeedEnd,
        uint256 _privateSaleStart,
        uint256 _privateSaleEnd,
        uint256 _publicSaleStart,
        uint256 _publicSaleEnd
    ) external onlyOwner {
        preSeedPrice = _preSeedPrice;
        privateSalePrice = _privateSalePrice;
        publicSalePrice = _publicSalePrice;
        preSeedStart = _preSeedStart;
        preSeedEnd = _preSeedEnd;
        privateSaleStart = _privateSaleStart;
        privateSaleEnd = _privateSaleEnd;
        publicSaleStart = _publicSaleStart;
        publicSaleEnd = _publicSaleEnd;
    }

    function buyTokens() external payable {
        uint256 tokens;
        if (block.timestamp >= preSeedStart && block.timestamp <= preSeedEnd) {
            require(
                currentPhase == SalePhase.PreSeed,
                "Pre-Seed sale is not active"
            );
            tokens = msg.value / preSeedPrice;
        } else if (
            block.timestamp >= privateSaleStart &&
            block.timestamp <= privateSaleEnd
        ) {
            require(
                currentPhase == SalePhase.PrivateSale,
                "Private sale is not active"
            );
            tokens = msg.value / privateSalePrice;
        } else if (
            block.timestamp >= publicSaleStart &&
            block.timestamp <= publicSaleEnd
        ) {
            require(
                currentPhase == SalePhase.PublicSale,
                "Public sale is not active"
            );
            tokens = msg.value / publicSalePrice;
        } else {
            revert("Sale is not active");
        }

        require(tokens > 0, "Insufficient funds to buy tokens");

        governor.distributeTokens(msg.sender, tokens);
    }

    function setSalePhase(SalePhase phase) external onlyOwner {
        currentPhase = phase;
    }

    function burnUnsoldTokens(uint256 amount) external onlyOwner {
        governor.burnUnsoldTokens(amount);
    }
}
