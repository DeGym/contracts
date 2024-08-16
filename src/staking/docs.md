# StakeManager and BondPool Frontend Integration Guide

This guide provides instructions for integrating the StakeManager and BondPool contracts with a Next.js frontend using MetaMask and web3.js.

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