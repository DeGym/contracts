// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract DeGymToken is ERC20, ERC20Burnable, AccessManaged, ERC20Permit {
    uint256 private _cap;

    event CapUpdated(uint256 newCap);

    constructor(
        address initialAuthority,
        uint256 initialCap
    )
        ERC20("DeGymToken", "DGYM")
        AccessManaged(initialAuthority)
        ERC20Permit("DeGymToken")
    {
        require(initialCap > 0, "ERC20Capped: cap is 0");
        _cap = initialCap * (10 ** decimals());
        _mint(msg.sender, 1000000000 * 10 ** decimals());
    }

    function cap() public view returns (uint256) {
        return _cap;
    }

    function setCap(uint256 newCap) public restricted {
        require(
            newCap >= totalSupply(),
            "New cap must be greater than or equal to total supply"
        );
        _cap = newCap * (10 ** decimals());
        emit CapUpdated(_cap);
    }

    function mint(address to, uint256 amount) public restricted {
        _mintCapped(to, amount);
    }

    function _mintCapped(address account, uint256 amount) internal {
        require(totalSupply() + amount <= _cap, "ERC20Capped: cap exceeded");
        _mint(account, amount);
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20) {
        super._update(from, to, value);
    }
}
