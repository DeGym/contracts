// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DeGymToken is ERC20, ERC20Capped, ERC20Permit, ERC20Votes {
    constructor(
        uint256 _maxSupply,
        uint256 _initialSupply
    ) ERC20("DeGym Token", "DGYM") ERC20Capped(_maxSupply * 10 ** decimals()) {
        require(
            _initialSupply <= _maxSupply,
            "Initial supply cannot exceed max supply"
        );
        _mint(msg.sender, _initialSupply * 10 ** decimals());
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    // The functions below are overrides required by Solidity.

    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._update(from, to, amount);
    }

    function nonces(
        address owner
    ) public view virtual override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
