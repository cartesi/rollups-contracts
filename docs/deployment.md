# Deployment Guide

This document aims to streamline the process of deploying
the Cartesi Rollups contracts to EVM-compatible blockchains.

## Steps

1. Make sure the correct version of Foundry is installed.
   If necessary, consult the [Getting Started](../README.md#getting-started) section.

2. Install the project dependencies through Soldeer.

```bash
forge soldeer install
```

3. Set the `RPC_URL` environment variable to the JSON-RPC API entrypoint of the target chain.
   You can use a public JSON-RPC provider (e.g. from [ChainList](https://chainlist.org/))
   or a service like [Alchemy](https://www.alchemy.com/) or [Infura](https://www.infura.io/).
   For example, let us assume we want to deploy to Ethereum Mainnet.

```bash
RPC_URL='https://ethereum-rpc.publicnode.com'
```

4. Simulate the deployment in the target chain.
   If any warnings arise, please consult the [Troubleshooting](#troubleshooting) section and address them.
   Ignoring such warnings is strongly discouraged.

```bash
./script/deploy.sh --rpc-url "$RPC_URL"
```

5. If simulation succeeds without warnings, check if a deployment cost estimate (like the one below) is displayed.
   If so, you may fund your wallet with the estimated amount.
   If not, this means that all contracts have been deployed to the target chain already!

```
==========================

Chain 1

Estimated gas price: 0.082096297 gwei

Estimated total gas used for script: 6223948

Estimated amount required: 0.000510963083520556 ETH

==========================
```

6. Execute the deployment script in broadcast mode by passing the `--broadcast` option.
   You may want to also verify the contracts on Sourcify by passing the `--verify` option.
   Depending on the nature of your wallet, you will need to pass different options.
   You may learn more about wallet configuration by providing the `--help` option.
   For your convenience, here are the most commonly-used wallet options:

   - Private key (plain text): `--private-key <PK>`
   - Keystore (encrypted file): `--keystore <PATH>`, `--account <NAME>`
   - Ledger (hardware wallet): `--ledger`
   - Trezor (hardware wallet): `--trezor`
   - AWS (key management system): `--aws`
   - GCP (key management system): `--gcp`

## Troubleshooting

### EIP-3855 is not supported in one or more of the RPCs used

[EIP-3855](https://eips.ethereum.org/EIPS/eip-3855) proposed the introduction of the `PUSH0` (`0x5f`) instruction,
aiming to reduce the size of contract bytecode, and, therefore, deployment costs.
It was included in the Shanghai protocol upgrade, which turned effective in Ethereum Mainnet on April 2023.
Before such upgrade, the `0x5f` opcode did not exist, and therefore its execution would revert.
Deploying contracts with such opcode to networks that did not upgrade to Shanghai is therefore discouraged.
One workaround is to compile the contracts targeting the Paris protocol version by passing the `--evm-version paris` option.
The warning might still appear, but the contract bytecode should not contain the `0x5f` opcode.
