# StakeManager and BondPool Frontend Integration Guide

This guide provides comprehensive instructions for integrating the StakeManager and BondPool contracts with a Next.js frontend using MetaMask and web3.js.

## Contract Overview

### StakeManager

The StakeManager contract is responsible for managing the overall staking system. It handles the deployment of BondPools, tracks total staked amounts and bond weights, and manages reward distribution.

Key features:
- Deploy individual BondPools for users
- Update and distribute rewards
- Manage global staking parameters (decay constant, basis points)

### BondPool

The BondPool contract represents an individual user's staking pool. It allows users to create bonds, unbond their tokens, and manage their rewards.

Key features:
- Create bonds with specific amounts and lock durations
- Unbond tokens after the lock period
- Calculate and update bond weights
- Manage individual user rewards

## Setup

1. Install required dependencies:
   ```bash
   npm install web3 @metamask/detect-provider
   ```

2. Create a new file `src/utils/web3.js` for web3 initialization:
   ```javascript
   import Web3 from 'web3';
   import detectEthereumProvider from '@metamask/detect-provider';

   let web3Instance = null;

   export async function getWeb3() {
     if (web3Instance) {
       return web3Instance;
     }

     const provider = await detectEthereumProvider();

     if (provider) {
       web3Instance = new Web3(provider);
       return web3Instance;
     } else {
       throw new Error('Please install MetaMask!');
     }
   }
   ```

3. Create contract ABI files:
   - `src/contracts/StakeManager.json`
   - `src/contracts/BondPool.json`

   Populate these files with the respective contract ABIs.

4. Create a configuration file `src/config.js` to store contract addresses:
   ```javascript
   export const STAKE_MANAGER_ADDRESS = '0x...'; // Replace with actual address
   export const TOKEN_ADDRESS = '0x...'; // Replace with actual address
   ```

## UI Structure

Create the following components:

1. `src/components/ConnectWallet.js`: Button to connect MetaMask
2. `src/components/StakeManager.js`: Main component for StakeManager interactions
3. `src/components/BondPool.js`: Component for BondPool interactions
4. `src/components/CreateBondPool.js`: Form to create a new BondPool
5. `src/components/Bond.js`: Form to create a new bond
6. `src/components/Unbond.js`: Form to unbond
7. `src/components/ClaimRewards.js`: Button to claim rewards

## Implementation Details

### 1. ConnectWallet Component

```jsx
import { useState, useEffect } from 'react';
import { getWeb3 } from '../utils/web3';

export default function ConnectWallet({ onConnect }) {
  const [account, setAccount] = useState(null);

  async function connectWallet() {
    try {
      const web3 = await getWeb3();
      const accounts = await web3.eth.requestAccounts();
      setAccount(accounts[0]);
      onConnect(accounts[0]);
    } catch (error) {
      console.error('Failed to connect wallet:', error);
    }
  }

  useEffect(() => {
    async function checkConnection() {
      const web3 = await getWeb3();
      const accounts = await web3.eth.getAccounts();
      if (accounts.length > 0) {
        setAccount(accounts[0]);
        onConnect(accounts[0]);
      }
    }
    checkConnection();
  }, []);

  return (
    <div>
      {account ? (
        <p>Connected: {account}</p>
      ) : (
        <button onClick={connectWallet}>Connect Wallet</button>
      )}
    </div>
  );
}
```

### 2. StakeManager Component

```jsx
import { useState, useEffect } from 'react';
import { getWeb3 } from '../utils/web3';
import StakeManagerABI from '../contracts/StakeManager.json';

export default function StakeManager({ account }) {
  const [stakeManager, setStakeManager] = useState(null);
  const [totalStaked, setTotalStaked] = useState(0);

  useEffect(() => {
    async function initializeContract() {
      if (account) {
        const web3 = await getWeb3();
        const networkId = await web3.eth.net.getId();
        const deployedNetwork = StakeManagerABI.networks[networkId];
        const instance = new web3.eth.Contract(
          StakeManagerABI.abi,
          deployedNetwork && deployedNetwork.address,
        );
        setStakeManager(instance);
      }
    }
    initializeContract();
  }, [account]);

  useEffect(() => {
    async function fetchTotalStaked() {
      if (stakeManager) {
        const total = await stakeManager.methods.totalStaked().call();
        setTotalStaked(total);
      }
    }
    fetchTotalStaked();
  }, [stakeManager]);

  return (
    <div>
      <h2>Stake Manager</h2>
      <p>Total Staked: {totalStaked}</p>
      {/* Add other StakeManager interactions here */}
    </div>
  );
}
```

### 3. BondPool Component

```jsx
import { useState, useEffect } from 'react';
import { getWeb3 } from '../utils/web3';
import BondPoolABI from '../contracts/BondPool.json';

export default function BondPool({ account, bondPoolAddress }) {
  const [bondPool, setBondPool] = useState(null);
  const [totalBondWeight, setTotalBondWeight] = useState(0);

  useEffect(() => {
    async function initializeContract() {
      if (account && bondPoolAddress) {
        const web3 = await getWeb3();
        const instance = new web3.eth.Contract(
          BondPoolABI.abi,
          bondPoolAddress
        );
        setBondPool(instance);
      }
    }
    initializeContract();
  }, [account, bondPoolAddress]);

  useEffect(() => {
    async function fetchTotalBondWeight() {
      if (bondPool) {
        const weight = await bondPool.methods.getTotalBondWeight().call();
        setTotalBondWeight(weight);
      }
    }
    fetchTotalBondWeight();
  }, [bondPool]);

  return (
    <div>
      <h2>Bond Pool</h2>
      <p>Total Bond Weight: {totalBondWeight}</p>
      {/* Add Bond and Unbond components here */}
    </div>
  );
}
```

### 4. CreateBondPool Component

```jsx
import { useState } from 'react';
import { getWeb3 } from '../utils/web3';

export default function CreateBondPool({ account, stakeManager }) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  async function handleCreateBondPool() {
    setLoading(true);
    setError(null);
    try {
      const web3 = await getWeb3();
      await stakeManager.methods.deployBondPool().send({ from: account });
      // Handle success (e.g., show success message, update UI)
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div>
      <h3>Create Bond Pool</h3>
      <button onClick={handleCreateBondPool} disabled={loading}>
        {loading ? 'Creating...' : 'Create Bond Pool'}
      </button>
      {error && <p style={{ color: 'red' }}>{error}</p>}
    </div>
  );
}
```

### 5. Bond Component

```jsx
import { useState } from 'react';
import { getWeb3 } from '../utils/web3';

export default function Bond({ account, bondPool }) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  async function handleCreateBond() {
    setLoading(true);
    setError(null);
    try {
      const web3 = await getWeb3();
      // Call the bondPool contract method to create a new bond
      // with the required parameters (e.g., amount, duration)
      // and handle the transaction
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div>
      <h3>Create Bond</h3>
      <button onClick={handleCreateBond} disabled={loading}>
        {loading ? 'Creating...' : 'Create Bond'}
      </button>
      {error && <p style={{ color: 'red' }}>{error}</p>}
    </div>
  );
}
```

### 6. Unbond Component

```jsx
import { useState } from 'react';
import { getWeb3 } from '../utils/web3';

export default function Unbond({ account, bondPool }) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  async function handleUnbond() {
    setLoading(true);
    setError(null);
    try {
      const web3 = await getWeb3();
      // Call the bondPool contract method to unbond
      // with the required parameters (e.g., bondId)
      // and handle the transaction
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div>
      <h3>Unbond</h3>
      <button onClick={handleUnbond} disabled={loading}>
        {loading ? 'Unbonding...' : 'Unbond'}
      </button>
      {error && <p style={{ color: 'red' }}>{error}</p>}
    </div>
  );
}
```

### 7. ClaimRewards Component

```jsx
import { useState } from 'react';
import { getWeb3 } from '../utils/web3';

export default function ClaimRewards({ account, stakeManager }) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  async function handleClaimRewards() {
    setLoading(true);
    setError(null);
    try {
      const web3 = await getWeb3();
      await stakeManager.methods.claimRewards().send({ from: account });
      // Handle success (e.g., show success message, update UI)
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div>
      <button onClick={handleClaimRewards} disabled={loading}>
        {loading ? 'Claiming...' : 'Claim Rewards'}
      </button>
      {error && <p style={{ color: 'red' }}>{error}</p>}
    </div>
  );
}
```
## Integration Steps

1. Set up the Next.js project and install dependencies.
2. Create the utility files (`web3.js`, `config.js`) and components as described above.
3. In your main page or app component, use the `ConnectWallet` component to handle wallet connection.
4. Once connected, initialize the `StakeManager` component.
5. Use the `CreateBondPool` component to allow users to create their BondPool if they don't have one.
6. After a BondPool is created, initialize the `BondPool` component with the user's BondPool address.
7. Use the `Bond`, `Unbond`, and `ClaimRewards` components within the `BondPool` component to allow users to interact with their BondPool.

Remember to handle error states, loading indicators, and success messages appropriately in your UI to provide a smooth user experience.

## Security Considerations

- Always use `SafeERC20` functions when interacting with ERC20 tokens.
- Implement proper access control in your smart contracts (as done with `onlyRole` modifiers).
- Validate user inputs both on the frontend and in smart contracts.
- Consider implementing a circuit breaker or pause mechanism in case of emergencies.
- Regularly update dependencies and conduct security audits.

## Testing

Ensure comprehensive testing of both smart contracts and frontend components:

- Use Foundry for smart contract testing (as seen in the provided test files).
- Implement unit tests for React components using tools like Jest and React Testing Library.
- Conduct integration tests to ensure proper interaction between the frontend and smart contracts.

## Deployment

1. Deploy the `DeGymToken`, `StakeManager`, and other necessary contracts to your chosen network.
2. Update the `config.js` file with the deployed contract addresses.
3. Build and deploy your Next.js application to a hosting service of your choice.

Remember to test thoroughly on testnets before deploying to mainnet.