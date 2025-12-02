# Cartesi Rollups Deployment Tutorial (v2.0)

This tutorial provides a comprehensive guide for deploying a Cartesi Rollups Application. The deployment process described here uses *cast* from [Foundry](https://getfoundry.sh/) for interacting with smart contracts.

---

## 1. Prerequisites

First, please make sure the core contracts are deployed to the network you are trying to deploy you application to. This is explained in this [tutorial](./deploying.md).

Also, ensure the following dependencies are installed as specified in the [Getting Started](./../README.md#getting-started) section.

## 2. Deploying Your Application Using `ISelfHostedApplicationFactory`

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

> [!TIP] [Cannon](https://usecannon.com/) includes an interactive CLI!
> As an alternative you can also use Cannon interactive CLI to inspect deployed contracts, call functions on them, view state and logs 

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