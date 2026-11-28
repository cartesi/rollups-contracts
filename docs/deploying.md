# Cartesi Rollups Deployment Tutorial (v2.0)

This tutorial provides a comprehensive guide for deploying a Cartesi Rollups Core Contracts. The deployment process uses [Cannon](https://usecannon.com/) tool for reproducible deployments. This tutorial works whether you’re deploying locally for development or targeting a public testnet or mainnet.

---

## 1. Prerequisites

First, please make sure to follow the steps described in the [Getting Started](./../README.md#getting-started) section.

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

Now you can also deploy your Application contracts to your preferred chain. 