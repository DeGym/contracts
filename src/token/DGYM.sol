// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract DeGymToken is
    ERC20,
    ERC20Burnable,
    Ownable,
    ERC20Permit,
    ERC20Votes,
    AccessControl
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /**
     * The total supply of the token is set to 1_000_000_000. This establishes the upper limit
     * of tokens that will ever be in circulation on Ethereum network.
     */
    uint256 private _totalSupply = 1_000_000_000e18;

    /**
     *
     * Allocating 20% to the "Ecosystem Development Fund" is crucial for funding ongoing
     * development, research, and innovation within the token's ecosystem.
     */
    uint256 public ecosystemDevelopment = (_totalSupply * 20) / 100;

    /**
     * Allocating 15% of the total supply to the "Team Growth Fund" supports the team's
     * long-term commitment and incentivizes their continuous contribution to the project's
     * success.
     */
    uint256 public teamGrowth = (_totalSupply * 15) / 100;

    /**
     * Allocating 12.5% for the "Community Engagement Fund" fosters a strong, interactive
     * community. This fund can be used for community rewards or other engagement
     * initiatives.
     */
    uint256 public communityEngagement = (_totalSupply * 125) / 1000;

    /**
     * Allocating 12.5% for the "Marketing and Promotion Fund" ensures ample resources are available
     * for advertising, partnerships, and other promotional activities to increase the token's
     * visibility and adoption.
     */
    uint256 public marketingPromotion = (_totalSupply * 125) / 1000;

    /**
     * The remaining 40% of the tokens, referred to as _remainingTokens, are allocated to the
     * Deployer for purposes such as sales and ensuring liquidity post-listing. This large
     * allocation allows for significant market penetration and liquidity provision.
     */
    uint256 private _remainingTokens =
        _totalSupply -
            (teamGrowth +
                communityEngagement +
                marketingPromotion +
                ecosystemDevelopment);

    uint256 private _cap = 10_000_000_000e18;

    address public ecosystemDevelopmentWallet;
    address public teamGrowthWallet;
    address public communityEngagementWallet;
    address public marketingPromotionWallet;

    event CapUpdated(uint256 newCap);

    constructor(
        address initialOwner
    )
        ERC20("DeGym Token", "DGYM")
        Ownable(initialOwner)
        ERC20Permit("DeGym Token")
        ERC20Votes()
        AccessControl()
    {
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        _grantRole(MINTER_ROLE, initialOwner);

        ecosystemDevelopmentWallet = 0x609D40C1d5750ff03a3CafF30152AD03243c02cB;
        teamGrowthWallet = 0xaDcB2f54F652BFD7Ac1d7D7b12213b4519F0265D;
        communityEngagementWallet = 0x139780E08d3DAF2f72D10ccC635593cDB301B4bC;
        marketingPromotionWallet = 0x6BC8906aD6369bD5cfe7B4f2f181f0759A3D53b6;

        _mint(ecosystemDevelopmentWallet, ecosystemDevelopment);
        _mint(teamGrowthWallet, teamGrowth);
        _mint(communityEngagementWallet, communityEngagement);
        _mint(marketingPromotionWallet, marketingPromotion);
        _mint(msg.sender, _remainingTokens);
    }

    function cap() public view returns (uint256) {
        return _cap;
    }

    function setCap(uint256 newCap) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            newCap >= totalSupply(),
            "New cap must be greater than or equal to total supply"
        );
        _cap = newCap;
        emit CapUpdated(_cap);
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mintCapped(to, amount);
    }

    function _mintCapped(address account, uint256 amount) internal {
        require(totalSupply() + amount <= _cap, "ERC20Capped: cap exceeded");
        _mint(account, amount);
    }

    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    // The following functions are overrides required by Solidity.

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(
        address owner
    ) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
