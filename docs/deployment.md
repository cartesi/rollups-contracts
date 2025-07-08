# Cartesi Rollups Deployment Tutorial (v2.0)

This tutorial provides a comprehensive guide for deploying a Cartesi Rollups Application. It covers the deployment of both the Cartesi Rollups core contracts and your application-specific contracts. The deployment process leverages key tools like [Cannon](https://usecannon.com/) for reproducible deployments, and *cast* from [Foundry](https://getfoundry.sh/) for interacting with smart contracts. Whether you’re deploying locally for development or targeting a public testnet or mainnet, this tutorial will help you understand and execute each step with confidence.

---

## 1. Prerequisites

Before beginning, ensure your environment is correctly set up. This includes having:

* [Corepack](https://nodejs.org/api/corepack.html), which manages multiple Node.js package managers,
* [Foundry](https://book.getfoundry.sh/getting-started/installation) v1.1.0 or higher, a fast and modular toolkit for Ethereum application development.

Next, clone the Cartesi Rollups contracts repository and install its dependencies. This repository contains both the core smart contracts and the application-specific ones:

```bash
git clone https://github.com/cartesi/rollups-contracts.git
cd rollups-contracts
pnpm install
forge soldeer install
```

This setup provides you with all the components needed to work with the Cartesi Rollups contracts.

---

## 2. Running a Local Devnet with Cannon

To begin development or testing, you can simulate a full Cartesi devnet locally. This is useful for experimentation and validation before deploying to a live network.

To do so, run:

```bash
pnpm start
```

This command launches Cannon, which deploys the Cartesi Rollups core contracts.. These contracts will be deployed on a local Ethereum JSON-RPC instance at `127.0.0.1:8545`.

Once running, you can interact with the contracts in one of two ways:

* Pressing `i` in the terminal where Cannon is running, which provides a prompt interface.
* Using `cast` from a separate terminal session.

---

## 3. Deploying to Testnet or Mainnet

When ready to deploy on a live network, you must first identify the addresses of the already-deployed core contracts, which are required by your application.

### Simulate Deployment First (Recommended)

Before initiating a real deployment, it is strongly recommended to simulate the process to ensure correctness and identify potential issues early. This can be done using:

```bash
pnpm cannon build --rpc-url $RPC_URL --dry-run --impersonate-all
```

Simulating with `--dry-run` prevents any real transactions from being broadcast, while `--impersonate-all` allows Cannon to simulate signatures for all accounts involved.

---

### Deploying Core Contracts to a Real Network

Once you are confident with the simulated results, proceed to deploy the Cartesi Rollups core contracts using:

```bash
pnpm cannon build --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

After deployment, use the same `cannon inspect` command to confirm the contract addresses. These addresses will be required in the next stage when deploying your actual application.

> [!NOTE]  
> The deployment method is deterministic, this means the core contracts should always have the same address independently of the chain. This can be false for chains that do not support CREATE2.

---

## 4. Deploying Your Application Using `ISelfHostedApplicationFactory`

Cartesi Applications are deployed using the `ApplicationFactory`. This factory deploys your application contract, but for now, we can use the `SelfHostedApplicationFactory` which is an utility contract to communicate with both the `ApplicationFactory` and the `AuthorityFactory` which is an authoritary settlement module responsible to receive and provide claims. 

### Contract Functions

The `SelfHostedApplicationFactory` interface provides two key functions:

```solidity
function deployContracts(...) external returns (IApplication, IAuthority);
function calculateAddresses(...) external view returns (address, address);
```

The `deployContracts` function performs the actual deployment, while `calculateAddresses` can be used to determine the final contract addresses prior to deployment using deterministic inputs.

### Parameters Explained

| Parameter          | Description                                                  |
| ------------------ | ------------------------------------------------------------ |
| `authorityOwner`   | The Ethereum address that will own the `Authority` contract. This account is expected to run a cartesi-rollups-node, which is responsible for validating your application and submitting claims to the Cartesi Rollups framework. |
| `epochLength`      | Duration of each epoch (in seconds)       |
| `appOwner`         | The address authorized to update the application's outputs Merkle root validator, which defines the official state of the application's outputs and submits claims about them. |
| `templateHash`     | Application template hash obtained using `cartesi hash`      |
| `dataAvailability` | ABI-encoded configuration related to data availability       |
| `salt`             | A 32-byte salt used for deterministic `CREATE2` deployment   |

> [!TIP]
> A random salt can be generated with the following command: 
> `head -c 32 /dev/urandom | xxd -p -c 32 | sed 's/^/0x/'`

---

### a. Encode `dataAvailability`

The `dataAvailability` parameter must be ABI-encoded. To do this, use the `cast calldata` command:

```bash
cast calldata "FunctionSignature(type1,type2,...)" arg1 arg2 ...
```

#### For default InputBox usage:

```bash
cast calldata "InputBox(address)" <InputBox Address>
```

#### For advanced configurations such as Espresso:

```bash
cast calldata "InputBoxAndEspresso(address,uint256,uint32)" <InputBox Address> 1234 5678
```

---

### b. Calculate Deterministic Addresses

Before deploying, you can predict the addresses of your application and authority contracts using:

```bash
cast call $SELF_HOSTED_APPLICATION_FACTORY_ADDRESS \
  "calculateAddresses(address,uint256,address,bytes32,bytes,bytes32)(address,address)" \
  $AUTHORITY_OWNER $EPOCH_LENGTH $APP_OWNER $TEMPLATE_HASH $DATA_AVAILABILITY $SALT \
  --rpc-url $RPC_URL
```

---

### c. Deploy the Application + Authority

Finally, deploy your application using the `deployContracts` function. This will deploy both the `Application` and `Authority` contracts at the precomputed addresses:

```bash
cast send $SELF_HOSTED_FACTORY_ADDRESS \
  "deployContracts(address,uint256,address,bytes32,bytes,bytes32)" \
  $AUTHORITY_OWNER $EPOCH_LENGTH $APP_OWNER $TEMPLATE_HASH $DATA_AVAILABILITY $SALT \
  --private-key $DEPLOYER_PK --rpc-url $RPC_URL
```

After this transaction is confirmed, your Cartesi Rollups Application will be live and ready to process inputs through the deployed core and application contracts.

Now it's time to spin up the node!