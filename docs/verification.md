# Verification Guide

This document aims to streamline the process of verifying
the Cartesi Rollups contracts on block explorers and source-code repositories.

Verification ensures a good experience on Etherscan (and equivalent explorers)
for developers, auditors, and end users.
Contracts can be verified at deployment time through the `--verify` option
(see the [deployment guide](./deployment.md)),
but verification may fail for reasons unrelated to the deployment itself.
When that happens, the contracts are already deployed,
and the deployment script has nothing left to broadcast.
The `verify-*` Makefile targets described here read the deployment artifacts
and allow the user to attempt verification again, as many times as necessary.

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
since it is not backed by a public explorer.

## Steps

1. Make sure the correct version of Foundry is installed.

```bash
make check-foundry-version
```

2. Check out the same revision of the repository that was used for deployment.
   Verification compares the bytecode compiled locally
   with the bytecode deployed on-chain.
   Any divergence in source code, dependency versions, compiler version
   or compiler settings will cause verification to fail.
   If you are verifying the contracts of a given release, check out its tag.

3. Install the project dependencies through Soldeer.

```bash
forge soldeer install
```

4. Make sure the deployment artifacts of the target chain
   are available under the `deployments/<chain-id>` directory.
   If they are not, consult the [deployment guide](./deployment.md).

5. Optionally, you may configure a custom Ethereum JSON-RPC provider.
   Consult the [deployment guide](./deployment.md) for options.

6. By default, contracts are verified on [Sourcify](https://sourcify.dev/).
   If the `ETHERSCAN_API_KEY` environment variable is set,
   they are verified on the Etherscan-based explorer of the target chain instead.
   A single API key is accepted by every chain supported by the Etherscan V2 API.
   In order to verify on both providers, run the target twice:
   once with the variable set, and once without it.
   Note that the variable must be exported to the environment,
   because it is read by Forge, and not by Make.

```bash
export ETHERSCAN_API_KEY='<your-api-key>'
```

7. Initiate the verification process on the target chain.
   Verification is attempted for every contract listed in the deployment artifacts of that chain,
   one at a time, and the command waits for the result of each submission.
   Verification options are passed down through the `VERIFY_OPTS` variable.

```bash
make verify-eth-mainnet
```

8. Contracts that are already verified are skipped,
   so the targets are safe to run more than once
   (in other words, they are idempotent just like the deployment targets).
   If a single contract fails to verify,
   fix the underlying cause and simply run the target again.

## How it works

Deployment artifacts are stored as one JSON file per contract,
under the `deployments/<chain-id>` directory.
In order to avoid depending on external JSON processors (such as `jq`),
the `deployments/summary.txt` file is generated
by the `script/DeploymentSummary.s.sol` Forge script.
It lists every known deployment in textual form,
with one line per contract, containing its chain ID, name and address,
sorted numerically by chain ID and then by contract name.

```
1 ApplicationFactory 0x<address>
1 AuthorityFactory 0x<address>
11155111 ApplicationFactory 0x<address>
11155111 AuthorityFactory 0x<address>
```

Each `verify-<chain>` target filters that file by chain ID with `awk`,
and passes the resulting address and contract name pairs to `forge verify-contract`.
Passing the contract name explicitly spares Forge from having to identify
which artifact corresponds to the deployed bytecode.
The constructor arguments, in turn, are extracted from the on-chain creation code
through the `--guess-constructor-args` option.

The summary file is a regular Make target,
and is regenerated whenever a deployment artifact is newer than it.

This file is also useful on its own:
because deployments are deterministic,
two developers working on the same release
should be able to compare their summary files and attest no differences.

## Troubleshooting

### find: 'deployments': No such file or directory

The `deployments` directory does not exist,
which means there is nothing to verify.
Please review step 4 of the [Steps](#steps) section.
For the same reason, a `verify-<chain>` target succeeds without verifying anything
if there are no deployment artifacts for that particular chain.

### Contract source code already verified

This is not an error.
The contract had already been verified on the explorer,
so Forge skipped it and moved on to the next one.

### The deployed bytecode does not match the compiled one

Verification is only possible if the local build reproduces the deployed bytecode.
Please make sure you checked out the revision that was used for the deployment,
that dependencies were installed with `forge soldeer install`,
and that no compiler option was overridden.

### The target chain explorer is not Etherscan-based

The `verify-*` targets support Sourcify and Etherscan out of the box.
If you need a different verification provider,
you may override the verification command on the command line.

```bash
make verify-eth-mainnet VERIFY_OPTS="--verifier <verifier> --verifier-url <url>"
```
