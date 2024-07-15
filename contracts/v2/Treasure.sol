// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./StakeManager.sol";

contract Treasure is Ownable {
    IERC20 public daoToken;
    StakeManager public stakeManager;
    uint256 public decayConstant;
    uint256 public maxSupply;
    uint256 public currentSupply;

    mapping(address => bool) public supportedFiatTokens;
    mapping(address => uint256) public fiatTokenRewards;

    event FiatTokenAdded(address fiatToken);
    event FiatRewardsDeposited(address indexed fiatToken, uint256 amount);
    event RewardsDistributed(uint256 daoRewards, uint256 fiatRewards);

    constructor(
        address _daoToken,
        address _stakeManager,
        uint256 _decayConstant,
        uint256 _maxSupply,
        uint256 _initialSupply
    ) {
        daoToken = IERC20(_daoToken);
        stakeManager = StakeManager(_stakeManager);
        decayConstant = _decayConstant;
        maxSupply = _maxSupply;
        currentSupply = _initialSupply;
    }

    function addFiatToken(address fiatToken) external onlyOwner {
        supportedFiatTokens[fiatToken] = true;
        emit FiatTokenAdded(fiatToken);
    }

    function depositFiatRewards(address fiatToken, uint256 amount) external {
        require(supportedFiatTokens[fiatToken], "Fiat token not supported");
        IERC20(fiatToken).transferFrom(msg.sender, address(this), amount);
        fiatTokenRewards[fiatToken] += amount;
        emit FiatRewardsDeposited(fiatToken, amount);
    }

    function distributeRewards() external onlyOwner {
        uint256 totalStaked = stakeManager.totalStaked();
        uint256 daoRewards = calculateInflation();
        currentSupply += daoRewards;

        uint256 totalFiatRewards;
        for (address fiatToken : supportedFiatTokens) {
            totalFiatRewards += fiatTokenRewards[fiatToken];
        }

        for (address user : stakeManager.userStakePools()) {
            uint256 userStake = stakeManager.getUserStake(user);
            uint256 daoReward = (userStake / totalStaked) * daoRewards;
            UserStakePool(stakeManager.getUserStakePool(user)).receiveRewards(daoReward);

            for (address fiatToken : supportedFiatTokens) {
                uint256 fiatReward = (userStake / totalStaked) * fiatTokenRewards[fiatToken];
                stakeManager.addFiatReward(user, fiatToken, fiatReward);
                fiatTokenRewards[fiatToken] -= fiatReward;
            }
        }

        emit RewardsDistributed(daoRewards, totalFiatRewards);
    }

    function calculateInflation() public view returns (uint256) {
        uint256 inflationRate = decayConstant * (maxSupply - currentSupply) / maxSupply;
        return currentSupply * inflationRate;
    }

    function setDecayConstant(uint256 newDecayConstant) external onlyOwner {
        decayConstant = newDecayConstant;
    }
}
