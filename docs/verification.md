# Verification Guide

This document aims to streamline the process of verifying
the Cartesi Rollups contracts on block explorers and source-code repositories.

Verification ensures a good experience on Etherscan (and equivalent explorers)
for developers, auditors, and end users.
Contracts could be verified at deployment time through the `--verify` option
but verification can fail for reasons unrelated to the deployment itself.
If that were to happen, the contracts would already deployed,
and the deployment script would have nothing left to broadcast.
The `verify-*` Makefile targets described here read the deployment artifacts
and allow the user to attempt verification as many times as necessary.

## Supported networks

| Network | Chain ID | Target |
| :- | :- | :- |
| Ethereum Mainnet | 1 | `verify-eth-mainnet` |
| Ethereum Sepolia | 11155111 | `verify-eth-sepolia` |
| OP Mainnet | 10 | `verify-opt-mainnet` |
| OP Sepolia | 11155420 | `verify-opt-sepolia` |
| Base Mainnet | 8453 | `verify-base-mainnet` |
| Base Sepolia | 84532 | `verify-base-sepolia` |
| Arbitrum Mainnet | 42161 | `verify-arb-mainnet` |
| Arbitrum Sepolia | 421614 | `verify-arb-sepolia` |

There are also three aggregate targets:
`verify-testnets`, `verify-mainnets`,
and `verify-livenets` (livenets being testnets and mainnets combined).
The local devnet is not covered by any of them,
since it is not backed by any public explorer.

## Steps

1. Make sure the correct version of Foundry is installed.

```bash
make check-foundry-version
```

2. Install the project dependencies through Soldeer.

```bash
forge soldeer install
```

3. Make sure the deployment artifacts of the target chain
   are available under the `deployments/<chain-id>` directory.
   If they are not, consult the [deployment guide](./deployment.md).

4. Optionally, you may configure a custom Ethereum JSON-RPC provider.
   See the [deployment guide](./deployment.md) for custom provider configuration.

5. Optionally, you may set `ETHERSCAN_API_KEY` for Etherscan verification.
   If unset, contracts are verified on [Sourcify](https://sourcify.dev/).
   A single API key is accepted by every chain supported by the Etherscan V2 API.
   If you wish to verify the contracts on both Sourcify and Etherscan,
   you may run the target twice: once with the variable set, and once without it.
   Note that the variable must be exported to the environment,
   because it is read by Forge, and not by Make.

```bash
export ETHERSCAN_API_KEY='<your-api-key>'
```

6. Initiate the verification process on the target chain.
   Verification is attempted for every contract listed in the deployment artifacts of that chain,
   one at a time, and the command waits for the result of each submission.
   Extra options to `forge verify-contract` can be passed down through the `VERIFY_OPTS` variable.

```bash
make verify-eth-mainnet [VERIFY_OPTS="..."]
```

7. Contracts that are already verified are skipped,
   so the targets are safe to run more than once
   (in other words, they are idempotent just like the deployment targets).
   If a single contract fails to verify,
   fix the underlying cause and simply run the target again.

## Troubleshooting

### No rule to make target 'deployments/<chain-id>/<contract-name>.txt'

This error indicates that you haven't deployed (or simulated the deployment)
of a contract you are attempting to verify. Please consult the deployment guide.

### Chain ... does not have a contract deployed at 0x...

This error indicates that either the contract simply wasn't deployed,
but it could also be the case that the deployed bytecode does not
match the compiled one, which leads to different `CREATE2` addresses.
In the first case, you must first deploy the contract before verifying it.
In the second case, you must ensure the local environment produces the
same bytecode as deployed.

### The deployed bytecode does not match the compiled one

Verification is only possible if the local build reproduces the deployed bytecode.
Please make sure you checked out the revision that was used for the deployment,
that dependencies were installed with `forge soldeer install`,
and that no compiler option was overridden.

### Contract source code already verified

This is not an error.
The contract had already been verified on the explorer,
so Forge skipped it and moved on to the next one.

