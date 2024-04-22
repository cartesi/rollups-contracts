# @cartesi/rollups

## 1.4.0

### Minor Changes

-   fe973472: Remove arbitrum goerli and optimism goerli configuration
-   c2c239e9: Add self-hosted application factory contract

## 1.3.1

### Patch Changes

-   78f25b1: support base sepolia

## 1.3.0

### Minor Changes

-   705bfa5: Support deployment to `base` network.

## 1.2.0

### Minor Changes

-   321e29a: Support deployment to `arbitrum_sepolia` and `optimism_sepolia` networks.
-   618121e: Bumped `@cartesi/util` from 6.0.0 to 6.1.0.

## 1.1.0

### Minor Changes

-   `AuthorityFactory`: Allows anyone to deploy `Authority` contracts. Supports deterministic deployment.
-   `HistoryFactory`: Allows anyone to deploy `History` contracts. Supports deterministic deployment.
-   `AuthorityHistoryPairFactory`: Allows anyone to deploy `Authority` and `History` contract pairs (such that `History` is owned by `Authority`, and `Authority` stores/retrieves claims from `History`). Supports deterministic deployment.
-   `Authority`: Removed deployment files and script.
-   `History`: Removed deployment files and script.

## 1.0.0

### Major Changes

-   Added `InvalidClaimIndex` error in `History` contract
-   Made portals and relays inherit `InputRelay`
-   Renamed `inboxInputIndex` to `inputIndex` in contracts
-   Deployed contracts deterministically with `CREATE2` factory
-   Renamed fields in `OutputValidityProof` structure
-   Updated `@cartesi/util` to 6.0.0
-   Removed base portal and relay contracts and interfaces
-   Removed `ConsensusCreated` event from `Authority` contract
-   Removed `IInputBox` parameter from `Authority` constructor
-   Fixed input size limit in `InputBox` contract

### Minor Changes

-   Added input relay interface and base contract
-   Deployed ERC-1155 portals
-   Added `RPC_URL` environment variable during deployment
-   Started using custom errors in contracts

### Patch Changes

-   Improved proof generation system for on-chain tests

## 0.9.0

### Major Changes

-   Simplified the on-chain architecture (not backwards-compatible)
-   `CartesiDApp` does not implement [EIP-2535](https://eips.ethereum.org/EIPS/eip-2535) anymore
-   Made each Portal a contract of their own, and shared amongst all the DApps
-   Made inputs added by Portals more compact by using the [packed ABI encoding](https://docs.soliditylang.org/en/latest/abi-spec.html#non-standard-packed-mode) instead of the standard one
-   Made ERC-20 deposits more generic by allowing base layer transfers to fail, and adding a boolean field signaling whether it was successful or not
-   Made ERC-721 deposits more generic by adding an arbitrary data field to be interpreted by the off-chain machine in the execution layer
-   Moved the input boxes of every DApp into a single, permissionless contract
-   Input boxes are now append-only—they are not cleared every new epoch (old Input Facet)
-   Modularized the consensus layer (a DApp can now seamlessly change its consensus model)
-   Modularized the claim storage layer (a consensus can now seamlessly change how it stores claims)
-   Voucher bitmask position is now determined by the input index (in the input box) and output index
-   Validators need now to specify the range of inputs of each claim they submit on-chain
-   Removed Setup Input
-   Removed Quorum consensus model implementation (up to 8 validators)
-   Removed Bank contract
-   Removed DApp configuration parameters related to the off-chain machine specs (now defined as constants)
-   Removed `epochIndex` field from `OutputValidityProof` struct
-   Removed headers from inputs added by trusted permissionless contracts like portals and relayers

### Minor Changes

-   Added Authority consensus model implementation (single validator)
-   Added Simple claim storage implementation (one claim per DApp)
-   Added Library that defines several constants related to the canonical off-chain machine
-   DApp Address Relay contract (allows the off-chain machine to know the DApp's address)

### Patch Changes

-   Added script for updating proofs used in unit tests
-   Adopted [Foundry](https://book.getfoundry.sh/) for contract testing (Hardhat is still being used for deployment)

## 0.7.0

### Major Changes

-   Documentation updates

## 0.6.0

### Minor Changes

-   Deploy to Arbitrum Goerli and Optimism Goerli

## 0.5.0

### Major Changes

-   Add `validateNotice` function to OutputFacet

## 0.3.0

### Major Changes

-   Moved logic from `erc721Deposit` function to `onERC721Received`
-   Renamed `ERC721Deposited` event to `ERC721Received` and added `operator` field
-   Validators who lost a dispute are removed from the validator set, and cannot redeem fees from previous claims
-   Changed the visibility of `Bank`'s state variables to private
-   Changed the visibility of `LibClaimsMask`'s functions to internal
-   Removed `erc721Deposit` function (call `safeTransferFrom` from the ERC-721 contract instead)
-   Removed `erc20Withdrawal` function call (vouchers now call `transfer` from the ERC-20 contract directly instead)
-   Gas optimizations

### Minor Changes

-   Add factory contract to deploy rollups diamond

### Patch Changes

-   Mermaid diagram of the on-chain rollups on README

## 0.2.0

### Major Changes

-   Bumped solc version to 0.8.13
-   Updated architecture to Diamonds design pattern
-   Added `FeeManagerFacet` and `Bank` contracts
-   Template Hash
-   Setup Input
-   NFT Portal
-   Removed Specific ERC-20 Portal

## 0.1.0

First release.
