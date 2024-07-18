// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Token is ERC20, Ownable {
    uint256 public maxSupply;
    uint256 public currentSupply;

    constructor() ERC20("DeGym Token", "DGYM") {
        maxSupply = 10_000_000_000 * 10 ** decimals();
        _mint(msg.sender, 1_000_000_000 * 10 ** decimals());
        currentSupply = 1_000_000_000 * 10 ** decimals();
    }

    function mint(address to, uint256 amount) external onlyOwner {
        require(currentSupply + amount <= maxSupply, "Exceeds max supply");
        _mint(to, amount);
        currentSupply += amount;
    }
    function setMaxSupply(uint256 newMaxSupply) external onlyOwner {
        require(
            newMaxSupply >= totalSupply(),
            "New max supply must be greater than or equal to current supply"
        );
        maxSupply = newMaxSupply;
    }
}
