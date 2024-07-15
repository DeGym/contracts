### DeGym Smart Contract System V2

This document provides a comprehensive overview of the smart contract system and the reward program in DeGym. It highlights the key improvements made in version 2, the modular structure of the contracts, and the inflation mechanism used to calculate rewards. The UML diagram provides a visual representation of the relationships between the contracts, making it easier to understand the system's architecture.

## Overview

This system consists of six primary smart contracts that handle the management of DeGym tokens, staking, vouchers, gym listings, check-ins, and governance.

## Contracts

### Token.sol
- **Purpose**: Manages the issuance and transfer of DGYM tokens.
- **Key Functions**:
  - `transfer`: Transfers DGYM tokens from one account to another.
  - `balanceOf`: Retrieves the balance of DGYM tokens for a specific account.

### VoucherManager.sol
- **Purpose**: Manages the issuance and management of vouchers (NFTs).
- **Key Functions**:
  - `purchaseVoucher`: Allows users to purchase vouchers using fiat tokens.
  - `upgradeVoucher`: Upgrades a voucher to a higher tier.
  - `renewVoucher`: Renews a voucher for an additional duration.
  - `downgradeVoucher`: Downgrades a voucher to a lower tier.
  - `getVoucherDetails`: Retrieves details of a specific voucher.
  - `setBasePrice`: Sets the base price for vouchers.
  - `setListingFactor`: Sets the listing factor for gyms.

### Checkin.sol
- **Purpose**: Manages the check-in process using vouchers and triggers payment.
- **Key Functions**:
  - `checkin`: Allows users to check in to gyms using their vouchers.
  - Validates if the tier of the voucher matches with the tier of the gym.
  - Ensures that the gym accepts the fiatToken of the given voucher.
  - Checks the eligibility of the gym based on the staked amount.

### GymManager.sol
- **Purpose**: Manages gym catalog, CRUD operations for gyms, and validates gym stakes based on counterpart stakes.
- **Key Functions**:
  - `addGym`: Adds a gym with a specific tier, geolocation, metadata, and acceptable fiat tokens.
  - `updateGym`: Updates the details of an existing gym.
  - `removeGym`: Removes a gym from the catalog.
  - `getGymDetails`: Retrieves details of a specific gym.
  - Validates gym registration based on the owner's staked DGYM amount (base_price * 50 per gym listed).
  - `listGym`: Lists a gym with a specific tier and staked amount.
  - `setRegisteringFactor`: Sets the listing factor for gyms.

### StakeManager.sol
- **Purpose**: Manages the deployment of user-specific stake pools and staking parameters.
- **Key Functions**:
  - `deployUserStakePool`: Deploys a user-specific stake pool contract.
  - `getUserStakePool`: Retrieves the address of a user-specific stake pool.
  - `distributeRewards`: Distributes rewards based on calculated inflation.
  - `distributeFiatRewards`: Distributes fiat token rewards based on the total staked amount.
  - `claimFiatRewards`: Allows users to claim their fiat token rewards.

### UserStakePool.sol
- **Purpose**: Manages the staking and reward distribution for a specific user.
- **Key Functions**:
  - `stake`: Allows the user to stake DGYM tokens with a specified lock duration and compound setting.
  - `unstake`: Allows the user to unstake their tokens after the lock duration has passed.
  - `receiveRewards`: Receives rewards from the StakeManager.
  - `claimDGYMRewards`: Allows the user to claim their DGYM rewards.
  - `calculateTotalStakedDuration`: Calculates the total weighted duration of staked tokens.
  - `calculateRewards`: Calculates the rewards based on the staked amount and lock duration.

### Treasure.sol
- **Purpose**: Manages the distribution of multiple fiat tokens and DGYM inflation.
- **Key Functions**:
  - `addFiatToken`: Adds a new fiat token to the treasury.
  - `depositFiatRewards`: Deposits fiat token rewards into the treasury.
  - `distributeRewards`: Distributes DGYM and fiat token rewards to user stake pools.
  - `setDecayConstant`: Sets the decay constant for inflation calculation.

### Governance.sol
- **Purpose**: Manages governance over base prices, listing factors, and staking parameters.
- **Key Functions**:
  - `changeBasePrice`: Allows changing the base price for vouchers and gym listings.
  - `changeListingFactor`: Allows changing the listing factor for gyms.
  - `changeDecayConstant`: Allows changing the decay constant for staking.
  - `changeVoucherManagerBasePrice`: Allows changing the base price for specific voucher managers (e.g., USDT).
  - `changeTreasureInflationParams`: Allows changing the inflation parameters and constants for the Treasure contract.



## Inflation Mechanism

### Inflation Rate Calculation
The inflation rate is dynamically calculated based on the remaining supply ratio and a decay constant. The formula used is:

inflation_rate = decay_constant × ((max_supply−current_supply​)/max_supply)

Where:
- `decay_constant` is 0.8.
- `current_supply` is the total supply of DGYM at the time of calculation.
- `max_supply` is 10,000,000,000 DGYM.

### Weighted Stakes Calculation
The reward distribution is calculated based on the staked amount and the lock duration using the following formulas:

duration_weights=[log(duration+1) for stake, duration in users]
weighted_stakes=[stake×weight for (stake, duration), weight in zip(users, duration_weights)]weighted_stakes=[stake×weight for (stake, duration), weight in zip(users, duration_weights)]
total_weighted_stake=∑(weighted_stakes)total_weighted_stake=∑(weighted_stakes)

Each user's share and reward:
rewards=[(stake,duration,weight,weighted_stake,weighted_stake/total_weighted_stake×total_rewards) for (stake, duration), weight, weighted_stake in zip(users, duration_weights, weighted_stakes)]rewards=[(stake,duration,weight,weighted_stake,weighted_stake/total_weighted_stake×total_rewards) for (stake, duration), weight, weighted_stake in zip(users, duration_weights, weighted_stakes)]

## UML Diagram

```mermaid
classDiagram
  direction LR
  class Token {
    +transfer()
    +balanceOf()
  }
  class FiatToken {
    +transfer()
    +balanceOf()
  }
  class VoucherManager {
    +purchaseVoucher()
    +createVoucher()
    +getVoucherDetails()
    +upgradeVoucher()
    +renewVoucher()
    +downgradeVoucher()
    +setBasePrice()
    +setListingFactor()
  }
  class GymManager {
    +addGym()
    +updateGym()
    +removeGym()
    +getGymDetails()
    +setBasePrice()
    +setListingFactor()
  }
  class Checkin {
    +checkin()
  }
  class Governance {
    +changeBasePrice()
    +changeListingFactor()
    +changeDecayConstant()
    +changeVoucherManagerBasePrice()
    +changeTreasureInflationParams()
  }
  class StakeManager {
    +deployUserStakePool()
    +getUserStakePool()
    +distributeRewards()
  }
  class UserStakePool {
    +stake()
    +unstake()
    +receiveRewards()
    +claimDGYMRewards()
    +claimFiatRewards()
    +claimAllDGYMRewards()
    +claimAllFiatRewards()
    +calculateTotalStakedDuration()
    +calculateRewards()
  }
  class Treasure {
    +calculateInflation()
    +distributeRewards()
  }

  Token <|-- UserStakePool
  FiatToken <|-- VoucherManager
  Token <|-- GymManager
  VoucherManager <|-- Checkin
  GymManager <|-- Checkin
  VoucherManager <|-- Governance
  GymManager <|-- Governance
  StakeManager <|-- UserStakePool
  Governance <|-- StakeManager
  StakeManager <|-- Treasure
  UserStakePool <|-- Treasure

```