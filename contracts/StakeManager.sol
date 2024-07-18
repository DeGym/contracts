// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakeManager is Ownable {
    IERC20 public daoToken;
    mapping(address => address) public stakePools;
    address[] public supportedFiatTokens;

    uint256 public totalStaked;

    event StakePoolDeployed(address indexed stakeholder, address stakePool);
    event StakeUpdated(address indexed stakeholder, uint256 newTotalStaked);

    constructor(address _daoToken) {
        daoToken = IERC20(_daoToken);
    }

    function deployStakePool(address fiatToken) external {
        require(
            stakePools[msg.sender] == address(0),
            "Stake pool already exists"
        );
        StakePool stakePool = new StakePool(
            address(daoToken),
            fiatToken,
            msg.sender,
            address(this)
        );
        stakePools[msg.sender] = address(stakePool);
        emit StakePoolDeployed(msg.sender, address(stakePool));
    }

    function getStakePool(address stakeholder) external view returns (address) {
        return stakePools[stakeholder];
    }

    function updateTotalStaked(uint256 amount, bool isStaking) external {
        require(
            stakePools[msg.sender] != address(0),
            "Stake pool does not exist"
        );

        if (isStaking) {
            totalStaked += amount;
        } else {
            totalStaked -= amount;
        }

        emit StakeUpdated(msg.sender, totalStaked);
    }

    function addSupportedFiatToken(address fiatToken) external onlyOwner {
        supportedFiatTokens.push(fiatToken);
    }

    function getTotalLockedDGYM() public view returns (uint256) {
        return totalStaked;
    }

    function getTotalUnlockedDGYM() public view returns (uint256) {
        uint256 totalSupply = daoToken.totalSupply();
        return totalSupply - totalStaked;
    }
}
