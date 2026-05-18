---
"@cartesi/rollups": minor
---

Distribute deterministic deployment addresses as `rollups-contracts-<version>-deployment-addresses.tar.gz` release artifacts.
The tarball contains `deployments/<chain-id>/<contract>.json` files for Ethereum, Optimism, Base, and Arbitrum mainnets and their Sepolia testnets.
Clients should check whether `eth_getCode` (or `cast code`) returns non-empty bytecode at any given address before using it.
Devnet deployment addresses are still distributed through `rollups-contracts-<version>-anvil-<foundry-version>.tar.gz`.
