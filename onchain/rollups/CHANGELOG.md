# @cartesi/rollups

## 2.0.0-rc.0

### Major Changes

-   d8561fe3: Modified the `OutputValidityProof` struct:

    -   Collapsed the `vouchersEpochRootHash` and `noticesEpochRootHash` fields into a single `outputsEpochRootHash` field
    -   Added an `inputRange` field

-   d8561fe3: Modified the ERC-20 deposit input:

    -   Removed the `success` field, because the ERC-20 portal now only adds inputs for successful deposits.

-   d8561fe3: Modified the `CanonicalMachine` library:

    -   Collapsed the `VOUCHER_METADATA_LOG2_SIZE` and `NOTICE_METADATA_LOG2_SIZE` constants into a single `OUTPUT_METADATA_LOG2_SIZE` constant (with the same value).
    -   Collapsed the `EPOCH_VOUCHER_LOG2_SIZE` and `EPOCH_NOTICE_LOG2_SIZE` constants into a single `EPOCH_OUTPUT_LOG2_SIZE` constant (with the same value).
    -   Updated the value of the `INPUT_MAX_SIZE` constant to reflect a change in the off-chain machine.

-   d8561fe3: Modified the `EtherPortal` contract:

    -   Made it support the following interfaces (as in EIP-165):

        -   `IERC165`
        -   `IInputRelay`
        -   `IEtherPortal`

-   d8561fe3: Modified the `AbstractConsensus` contract:

    -   Removed the `join` function
    -   Implemented the `getEpochHash` function
    -   Added an internal `_acceptClaim` function

-   13eb18a4: Inputs are now blockchain-agnostic and self-contained blobs.
-   4e2533ef: Include application address in `EvmAdvance` input.
-   d8561fe3: Modified the `IInputRelay` interface:

    -   Made it inherit from `IERC165`

-   d8561fe3: Modified the `ERC1155BatchPortal` contract:

    -   Made it support the following interfaces (as in EIP-165):

        -   `IERC165`
        -   `IInputRelay`
        -   `IERC1155BatchPortal`

-   d8561fe3: Modified the `IEtherPortal` interface:

    -   Added an `EtherTransferFailed` error.

-   d8561fe3: Bumped `@openzeppelin/contracts` from `4.9.2` to `5.0.0`.
-   d8561fe3: Moved `Proof` to a dedicated file in the `common` directory.
-   f39e4ef0: Added a `value` field to vouchers.
-   d8561fe3: Moved `OutputValidityProof` to a dedicated file in the `common` directory.
-   d8561fe3: Modified the `ICartesiDAppFactory` interface:

    -   Renamed it as `IApplicationFactory`.
    -   Added the following parameters to its functions and events:

        -   `inputBox`
        -   `inputRelays`

-   d8561fe3: Modified the `CartesiDApp` contract:

    -   Renamed it as `Application`.
    -   Added the following parameters to its constructor:

        -   `inputBox`
        -   `inputRelays`

    -   Made it support the following interfaces (as in EIP-165):

        -   `IApplication`
        -   `IERC721Receiver`

    -   Removed the `withdrawEther` function.
    -   Removed the `OnlyApplication` error.
    -   Removed the `EtherTransferFailed` error.

-   d8561fe3: Modified the `ERC1155SinglePortal` contract:

    -   Made it support the following interfaces (as in EIP-165):

        -   `IERC165`
        -   `IInputRelay`
        -   `IERC1155SinglePortal`

-   d8561fe3: Removed:

    -   the `History` contract.
    -   the `IHistory` interface.
    -   the `HistoryFactory` contract.
    -   the `IHistoryFactory` interface.
    -   the `AuthorityHistoryPairFactory` contract.
    -   the `IAuthorityHistoryPairFactory` interface.
    -   the `OutputEncoding` library.
    -   the `LibInput` library.
    -   the `ApplicationAddressRelay` contract.
    -   the `IApplicationAddressRelay` interface.

-   8892a88b: Include chain ID in `EvmAdvance` input.
-   d8561fe3: Modified the `ICartesiDApp` interface:

    -   Renamed it as `IApplication`.
    -   Made it inherit from:

        -   `IERC721Receiver`.
        -   `IERC1155Receiver` (which inherits from `IERC165`).

    -   Modified the `executeVoucher` function:

        -   Renamed it as `executeOutput`.
        -   Errors raised by low-level calls are bubbled up.
        -   Changed the type of the `proof` parameter to `OutputValidityProof`.
        -   Removed the boolean return value.

    -   Modified the `validateNotice` function:

        -   Renamed it as `validateOutput`.
        -   Changed type of the `proof` parameter to `OutputValidityProof`.
        -   Removed the boolean return value.

    -   Modified the `VoucherExecuted` event:

        -   Renamed it as `OutputExecuted`.
        -   Split the `voucherId` parameter into `inputIndex` and `outputIndexWithinInput` parameters.
        -   Added an `output` parameter.

    -   Modified the `wasVoucherExecuted` function:

        -   Renamed it as `wasOutputExecuted`.

    -   Added a `getInputBox` function.
    -   Added a `getInputRelays` function.
    -   Added an `InputIndexOutOfRange` error.
    -   Added an `OutputNotExecutable` error.
    -   Added an `OutputNotReexecutable` error.
    -   Added an `IncorrectEpochHash` error.
    -   Added an `IncorrectOutputsEpochRootHash` error.
    -   Added an `IncorrectOutputHashesRootHash` error.

-   13eb18a4: Modified the `IInputBox` interface:

    -   Modified the `InputAdded` event:

        -   Removed the `sender` parameter.
        -   Changed the semantics of the `input` parameter.

    -   Added an `InputTooLarge` error.

-   d8561fe3: Modified the `CartesiDAppFactory` contract:

    -   Renamed it as `ApplicationFactory`.

-   d8561fe3: Modified the `InputRelay` contract:

    -   Made it support the following interfaces (as in EIP-165):

        -   `IERC165`
        -   `IInputRelay`

-   d8561fe3: Modified the `Authority` contract:

    -   Removed the `AuthorityWithdrawalFailed` error
    -   Removed the `NewHistory` event
    -   Removed the `getClaim` function
    -   Removed the `getHistory` function
    -   Removed the `join` function
    -   Removed the `migrateHistoryToConsensus` function
    -   Removed the `setHistory` function
    -   Removed the `submitClaim(bytes)` function
    -   Removed the `withdrawERC20Tokens` function
    -   Implemented the `submitClaim(address,(uint64,uint64),bytes32)` function

-   d8561fe3: Completely modified the `IConsensus` interface:

    -   Removed the `join` function
    -   Removed the `getClaim` function
    -   Removed the `ApplicationJoined` event
    -   Added a `submitClaim` function
    -   Added a `getEpochHash` function
    -   Added a `ClaimSubmission` event
    -   Added a `ClaimAcceptance` event

-   d8561fe3: Bumped the Solidity compiler from `0.8.19` to `0.8.23`.
-   d8561fe3: Modified the `IERC20Portal` interface:

    -   Added an `ERC20TransferFailed` error.

-   d8561fe3: Modified the `ERC20Portal` contract:

    -   Made it support the following interfaces (as in EIP-165):

        -   `IERC165`
        -   `IInputRelay`
        -   `IERC20Portal`

-   d8561fe3: Removed deployments to Goerli testnets (L1 and L2s).
-   d8561fe3: Modified the `ERC721Portal` contract:

    -   Made it support the following interfaces (as in EIP-165):

        -   `IERC165`
        -   `IInputRelay`
        -   `IERC721Portal`

### Minor Changes

-   d8561fe3: Added:

    -   an `Outputs` interface
    -   an `InputRange` struct
    -   a `LibInputRange` library
    -   a `Quorum` contract (which implements the `IConsensus` interface)
    -   a `QuorumFactory` contract
    -   an `IQuorumFactory` interface

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
