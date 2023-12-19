# @cartesi/rollups

## 2.0.0

### Major Changes

-   9c586026: Changed the behavior of the `executeVoucher` function from the `CartesiDApp` contract to propagate any errors raised by the message call.
    This should allow users and developers to know the reason as to why a given voucher failed to execute.
    Front-ends should propagate the error message to the user to improve the UX.
    Smart contracts that call this function should either try to handle the error or propagate it.
-   cc3ae5c1: Removed `AuthorityHistoryPairFactory` and `IAuthorityHistoryPairFactory`.
    These contracts will no longer be necessary, given the refactor in the `Authority` contract.
-   2a84457c: Bumped Solidity to `0.8.20`.
    This change was made to work with `@openzeppelin/contracts@5.0.0`.
-   87cb24b1: Removed support to Goerli testnets (L1 and L2s).
    Goerli has been deprecated by the Ethereum Foundation in 2023.
    The EF advises users of Goerli to migrate their applications to Sepolia, which we support.
-   69bee531: Removed `HistoryFactory` and `IHistoryFactory`.
    These contracts will no longer be necessary, given the refactor in the `Authority` contract.
-   87f7b716: Moved the definition of the `OutputValidityProof` structure to its own file.
    This change was made to avoid coupling this structure with the `LibOutputValidation` library.
    Contracts that imported this structure from `contracts/library/LibOutputValidation.sol` must now import it from `contracts/common/OutputValidityProof.sol`.
-   705230f8: Changed `VoucherExecuted` event to have `inputIndex` and `outputIndexWithinInput` as parameters instead of `voucherPosition`.
    This change was made due to an internal change that involved transitioning from the homebrew `Bitmask` library to OpenZeppelin's `BitMaps` library.
    It is now easier for the off-chain to reason about `VoucherExecuted` events, since they don't have to decode `voucherPosition` into `inputIndex` and `outputIndexWithinInput` anymore.
    Off-chain components that listened to `VoucherExecuted` must now listen to the new event instead.
-   76234f7c: Bumped `@openzeppelin/contracts` to `5.0.0`. See the list of [breaking changes](https://github.com/OpenZeppelin/openzeppelin-contracts/releases/tag/v5.0.0).
-   94712486: Removed the boolean return value from the functions `executeVoucher` and `validateNotice` of the `ICartesiDApp` interface.
    This change was made because these functions would never return `false`.
    Contracts and EOAs that called these functions now shouldn't expect a boolean return value.
-   f5f37169: Moved the definition of the `Proof` structure to its own file.
    This change was made to avoid coupling this structure with the `ICartesiDApp` interface.
    Contracts that imported this structure from `contracts/dapp/ICartesiDApp.sol` must now import it from `contracts/common/Proof.sol`.
-   96c0241c: Removed `History`.
    This contract will no longer be necessary, given the refactor in the `Authority` contract.
-   e0caa166: Removed `EtherTransferFailed()` error from `EtherPortal`.
    We're now using OpenZeppelin's `Address` library for the Ether portal, which already raises `FailedInnerCall()` in case of failure.
    Callers should now expect `FailedInnerCall()` instead of `EtherTransferFailed()` for failed Ether transfers.
-   d0634784: Removed the boolean `success` flag from ERC-20 deposit inputs.
    This change was made because this flag would always be `true`, giving no extra information to the DApp back-end.
    Consumers of this input should be aware of the new encoding.
-   40a0d07c: Added a `getInputBox` function to the `ICartesiDApp` interface.
    Added an `IInputBox` parameter to the functions and events of the `ICartesiDAppFactory` interface, and to the constructor of the `CartesiDApp` contract.
    This change was made to allow the node to discover the `IInputBox` contract to listen `InputAdded` events from, just by calling the function from the `ICartesiDApp` interface.
    Likewise, users can now know which `IInputBox` contract they should add inputs to, directly or indirectly, in order to communicate with a given DApp.
    Users of `ICartesiDAppFactory` should now pass an extra `IInputBox` parameter on deployment.
    Off-chain components should now listen to the new `ApplicationCreated` event.
-   28777dc3: Implemented EIP-165 for CartesiDApp contract.
    Also updated `ICartesiDApp` to include `IERC721Receiver`, `IERC1155Receiver` (which inherits from `IERC165`).
    We made the `ICartesiDApp` interface inherit from `ERC165` so that it would be possible to detect contracts that do not support such interface.
-   e2bc71cc: Removed `AuthorityWithdrawalFailed` error from the `Authority` contract.
    This error was removed because it would only be raised by the `withdrawERC20Tokens` function, which was removed.
-   90d5ccc3: Implemented EIP-165 for input relays.
    This is because `CartesiDApp` can return an array of input relays. EIP-165 helps to tell which interfaces the relay implements.
-   e2bc71cc: Removed the `withdrawERC20Tokens` function from `Authority` contract.
    This function was removed due to the lack of usage, and because implementing a similar function for `Quorum` would not be possible with `@openzeppelin/contracts@5.0.0`.
    Users should not transfer ERC-20 tokens to `Authority` contracts, as it now no longer defines an entry point for withdrawing them, leaving them stuck there forever.
    Users should not try to call this function, as it is no longer present in the contract.
-   3baed5f7: Refactored the `IConsensus` interface for better interaction with the Cartesi Rollups node.
    Added `InputIndexOutOfRange` error to `ICartesiDApp` interface to improve UX of voucher execution.
    Updated the `AbstractConsensus` contract to partially implement the new `IConsensus` interface.
    Updated the `Authority` contract to implement the new `IConsensus` interface.
    Updated the `CartesiDApp` contract to call `getEpochHash` instead of `getClaim`, and to not call `join`.
    Replaced the `bytes context` field from the `Proof` structure with an `InputRange inputRange` field.
    Removed the `getHistory`, `setHistory` and `migrateHistoryToConsensus` functions and `NewHistory` event from the `Authority` contract.
    Contracts that implemented the old `IConsensus` interface and wish to implement the new one must be adapted.
    Contracts that implement the new `IConsensus` interface are not backwards compatible with old `CartesiDApp` contracts, since they expect the consensus to expose a `join` function.
    Components that would call the `getClaim` function must now call the `getEpochHash` function while passing an input range instead of a "context" blob.
    Components that would call the `join` function should not call it anymore, as it is no longer declared in the new interface.
    Components that would listen to the `ApplicationJoined` event should not listen to it anymore, as it is no longer declared in the new interface.
-   00a5b143: Changed the ERC-20 portal to revert whenever `transferFrom` returns `false`.
    This change was made to prevent DApp back-end developers from accepting failed transfers by not checking the `success` flag of ERC-20 deposit inputs.
    We used OpenZeppelin's `SafeERC20` to deliver an even safer and user-friendly experience through the ERC-20 portal.
-   1da601ad: Added a `getInputRelays` function to the `ICartesiDApp` interface.
    Added `inputRelays` parameter to the functions and events of the `ICartesiDAppFactory` interface, and to the constructor of the `CartesiDApp` contract.
    This change was made to allow the node to discover the input relay contracts that the DApp back-end may expect inputs from, just by calling the `getInputRelays` function from the `ICartesiDApp` interface.
    Likewise, users can now know which input relay contracts they should add inputs through, in order to communicate with a given DApp.
    Users of `ICartesiDAppFactory` should now pass an extra `inputRelays` array parameter on deployment.
    Off-chain components should now listen to the new `ApplicationCreated` event.
-   e0caa166: Changed the type of the `dapp` parameter of the `depositEther` function from `address` to `address payable`.
    This change was made because we're now using OpenZeppelin's `Address` library internally to do the Ether transfer.
    It also makes sense for this address to be payable since we are transfering Ether to it.
    Callers should cast their addresses as `payable` to call this function now.

### Minor Changes

-   e6110bc6: Added `InputRange` structure.
    This definition is used by the new `IConsensus` interface and `Proof` structure.

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
