# @cartesi/rollups

## 3.0.0-alpha.9

### Minor Changes

- Import contracts using relative paths only, allowing clients to import test and script contracts

### Patch Changes

- Import `LOG2_MAX_OUTPUTS` constant from `EmulatorConstants` instead of hard-coding it in `CanonicalMachine`; the value is still 63
- Override file permissions with `--mode=a=rX,u+w` when bundling release artifacts
- Improve Rust bindings CI job performance by skipping test contracts build
- Change `build` Make target to skip test build (only necessary when running tests, see new `build-all` target)
- Add Make targets: `build-all`, `clean`, `install-deps`, and `test`
- Adjust documentation and CI to use new Make targets
- Makefile improvements

## 3.0.0-alpha.8

### Minor Changes

- Add post-deployment verification through `verify-*` Makefile targets ([#548](https://github.com/cartesi/rollups-contracts/issues/548))

  Contracts could be verified at deployment time through the `--verify` option, but verification can fail for reasons unrelated to the deployment itself, in which case the deployment script would have nothing left to broadcast. The new targets read the deployment artifacts instead, so verification can be attempted as many times as necessary. Contracts that are already verified are skipped, so the targets are idempotent, just like the deployment ones.

  - Add a `verify-<chain>` target for every supported livenet, which verifies every deployed core contract on that chain, one at a time
  - Add `verify-<chain>-<contract>` targets, for verifying a single core contract
  - Add the aggregate `verify-testnets`, `verify-mainnets` and `verify-livenets` targets (the devnet is not covered by any of them, as it is not backed by any public explorer)
  - Verify on Etherscan if `ETHERSCAN_API_KEY` is set, and on [Sourcify](https://sourcify.dev/) otherwise; extra options can be passed down to `forge verify-contract` through the `VERIFY_OPTS` variable
  - Document the process, along with troubleshooting instructions, in the new verification guide at `docs/verification.md`.

- Store deployment addresses in plaintext, besides JSON

  The deployment script now writes a `deployments/<chain-id>/<contract-name>.txt` file containing only the address, alongside the existing `.json` file. This lets the Makefile and the documentation read deployment addresses without taking `jq` as a dependency. The README example was updated accordingly, and now reads `cat deployments/31337/InputBox.txt`.

- Deprecate JSON deployment artifacts

  Internally, only plaintext artifacts are used, since they do not require JSON-processing tools like `jq`. Clients are advised to migrate. Once all main clients (`dave`, `rollups-node`, `rollups-ts` and `rollups-explorer`) have migrated to plaintext artifacts, we will remove the JSON artifacts.

- Add a `TestUsdc` token to the devnet

  It mocks the original USD Coin token, and represents amounts with 6 decimal places instead of the OpenZeppelin default of 18, so that front-ends can be exercised against realistic values. The devnet `TestUsdWithdrawalOutputBuilder` is now backed by `TestUsdc`, instead of `TestFungibleToken`. Like the other devnet tokens, `TestUsdc` is included in the published build artifacts and in the Rust bindings crate. The mint and burn entrypoints shared by the devnet fungible tokens were extracted into a new abstract `BaseTestFungibleToken` contract.

### Patch Changes

- Bump `cartesi-machine-solidity-step` from the `v0.15.0-test1` tag to the definitive `v0.15.0` tag ([#547](https://github.com/cartesi/rollups-contracts/issues/547))
- Bump the alloy version of the generated Rust bindings crate from 1.0 to 2
- Make `publish-soldeer-package` treat `0`, `n`, `no` and `false` as falsy values of `DRY_RUN`, so that the Soldeer-publishing workflow (which evaluates `DRY_RUN` to `false` on releases) actually publishes the Soldeer package instead of merely dry-running the process ([#542](https://github.com/cartesi/rollups-contracts/issues/542))
- Set `ALCHEMY_API_KEY` on the release-artifacts CI job, which simulates deployments to every supported network, so that the pipeline no longer depends on rate-limited public JSON-RPC providers
- Bundle release artifacts deterministically, through `tar --sort=name --mtime=@0 --owner=1000 --group=1000 --numeric-owner`
- Exclude the `unsafe-cheatcode` lint in `foundry.toml`, instead of disabling it at each call site
- Documentation improvements
- Makefile improvements
- CI actions bumps

## 3.0.0-alpha.7

### Major Changes

- Replace the generic data availability solution with an explicit input box contract ([#537](https://github.com/cartesi/rollups-contracts/pull/537))

  - Replace `getDataAvailability()` (returning `bytes`) with `getInputBox()` (returning `IInputBox`) in `IApplication`
  - Replace the `bytes dataAvailability` parameter with an `IInputBox inputBox` parameter in the `Application` constructor, in `IApplicationFactory` (`newApplication`, `calculateApplicationAddress`) and in `ISelfHostedApplicationFactory` (`deployContracts`, `calculateAddresses`)
  - Replace the `bytes dataAvailability` field with an `IInputBox inputBox` field in the `ApplicationCreated` event
  - Remove the `DataAvailability` library

- Make portals read the input box from the application contract instead of holding it as an immutable

  - Remove the `getInputBox()` function from `IPortal` and the `IInputBox` parameter from every portal constructor
  - Make `IPortal` inherit from `IApplicationChecker`, because deposits (since 3.0.0-alpha.2) may revert with `ApplicationNotDeployed`, `ApplicationReverted` or `IllformedApplicationReturnData`
  - Add an `InputBoxNotDeployed` error to `IApplicationChecker`, raised when the input box advertised by the application has no code
  - As a consequence, a deposit is now routed to the input box chosen by the application, instead of the one hard-wired into the portal

- Change the `submitClaim` function to prove that the post-epoch machine is manually yielded with an `rx accepted` reason ([#538](https://github.com/cartesi/rollups-contracts/issues/538))

  - Replace the `bytes32 outputsMerkleRoot` and `bytes32[] proof` parameters with `bytes32 machineMerkleRoot` and `MachineValidityProof proof` in `IConsensus.submitClaim` (implemented by `Authority` and `Quorum`)
  - Add the `MachineValidityProof` struct, which bundles three `LeafProof` structs proving the `iflags_Y` register, the HTIF `tohost` register and the first data block of the CMIO tx buffer
  - Add the `LeafProof` struct (a 32-byte data block plus its bottom-up siblings)
  - Remove the `InvalidOutputsMerkleRootProofSize` error from `IConsensus`, and make `IConsensus` inherit from the new `MachineValidationErrors` interface instead, which defines `InvalidSiblingsArrayLength`, `InvalidMachineMerkleProof`, `InvalidPostEpochMachineIflagsYRegister` and `InvalidPostEpochMachineHtifTohostRegister`
  - A machine that fails these checks may have reached an unrecoverable state, in which case the application should be foreclosed so that users can recover funds through emergency withdrawals and deposit refunds

- Require the account owner to occupy the last 20 bytes of every encoded account ([#540](https://github.com/cartesi/rollups-contracts/issues/540))

  - Account encodings remain application-specific, but must now end with the account owner address encoded as a 20-byte big-endian string, so that the node can extract owners from the accounts drive and serve owner-to-account-index lookups
  - Change the USD account encoding accordingly: the balance is now a `uint96` (up from `uint64`) stored little-endian in the first 12 bytes, and the owner address occupies the last 20 bytes
  - Require USD accounts to be exactly 32 bytes long (there is no more tail padding, and the account must fit in a single data block)
  - Replace the `AccountTooShort(uint64 attemptedAccountSize, uint64 minAccountSize)` error with `InvalidAccountSize(uint256 attemptedAccountSize, uint64 accountSize)` in `IWithdrawalOutputBuilderErrors`

- Treat `ERC` as a regular word in `camelCase` and `PascalCase` identifiers

  This is a mechanical rename (replace `ERC` with `Erc` in Cartesi-owned identifiers) motivated by Forge's Rust binding generation, which turned `IERC20Portal` into `ierc20_portal` instead of `i_erc20_portal`. Definitions imported from OpenZeppelin are unaffected.

  - Contracts: `ERC20Portal`, `ERC721Portal`, `ERC1155SinglePortal`, `ERC1155BatchPortal` and `SafeERC20Transfer` become `Erc20Portal`, `Erc721Portal`, `Erc1155SinglePortal`, `Erc1155BatchPortal` and `SafeErc20Transfer`
  - Interfaces: `IERC20Portal`, `IERC721Portal`, `IERC1155SinglePortal`, `IERC1155BatchPortal` and `ISafeERC20Transfer` become `IErc20Portal`, `IErc721Portal`, `IErc1155SinglePortal`, `IErc1155BatchPortal` and `ISafeErc20Transfer`
  - Deposit functions: `depositERC20Tokens`, `depositERC721Token`, `depositSingleERC1155Token` and `depositBatchERC1155Token` become `depositErc20Tokens`, `depositErc721Token`, `depositSingleErc1155Token` and `depositBatchErc1155Token`
  - `InputEncoding` functions: `encodeERC20Deposit`, `encodeERC721Deposit`, `encodeSingleERC1155Deposit` and `encodeBatchERC1155Deposit` become `encodeErc20Deposit`, `encodeErc721Deposit`, `encodeSingleErc1155Deposit` and `encodeBatchErc1155Deposit`
  - Errors: `ERC20TransferFailed` becomes `Erc20TransferFailed`

- Remove the `IApplicationForeclosure` and `IApplicationWithdrawal` interfaces, moving all of their definitions into `IApplication`

  The individual events, errors and functions are unchanged, but clients importing these two interfaces directly must now import `IApplication` instead. `IApplication` also inherits from `AddressErrors`, `BinaryMerkleTreeErrors`, `IRefundOutputBuilderErrors` and `IWithdrawalOutputBuilderErrors`.

- Reject deposits of fee-on-transfer ERC-20 tokens

  Some non-compliant ERC-20 tokens charge a fee per transfer, so the recipient balance grows by less than the transfer value. The ERC-20 portal now compares the application balance before and after the transfer and reverts unless the delta matches the deposited value exactly. This prevents the application from believing it holds more tokens than it does on the base layer, which would otherwise lead to insolvency and to withdrawal and refund outputs that cannot be executed.

  - Add the `Erc20TransferDecreasedApplicationBalance(uint256 balanceBefore, uint256 balanceAfter)` and `Erc20TransferValueIsNotBalanceDelta(uint256 value, uint256 balanceDelta)` errors to `IErc20Portal`

- Restrict consensus migration to the deployment block

  `migrateToOutputsMerkleRootValidator` now reverts with the new `NotDeploymentBlock` error if called in any block other than the one in which the application was deployed. This protects users from application owners who could otherwise take control of locked funds by swapping the outputs Merkle root validator; the owner now serves merely as an implementation detail that lets factories deploy application-consensus pairs in a single transaction.

- Remove the `appOwner` parameter from `ISelfHostedApplicationFactory.deployContracts` and `calculateAddresses`

  The factory now deploys the application under its own ownership and immediately renounces it, so self-hosted applications are ownerless from the start and can no longer migrate to another outputs Merkle root validator.

- Add a `wasInputFinalized(address appContract, uint256 inputIndex, uint256 blockNumber)` function to `IOutputsMerkleRootValidator`

  Implementers of this interface outside of this repository must implement the new function. `AbstractConsensus` (and therefore `Authority` and `Quorum`) implements it by comparing the block number against the application's first unprocessed block number.

- Add an `IRefundOutputBuilder` parameter to the `ApplicationFactory` constructor

  The refund output builder is a factory-wide immutable rather than a per-application parameter, so it is not part of `WithdrawalConfig` and is not passed to `newApplication`.

- Apply the checks-effects-interactions pattern to `executeOutput`, `issueRefund` and `withdraw`, and remove the `ReentrancyGuard`

  This is cheaper than acquiring and releasing a reentrancy lock (one fewer storage read and write), but it changes what on-chain observers see during the interaction: `wasOutputExecuted`, `wasRefundForInputIssued` and `wereAccountFundsWithdrawn` now return `true`, and the corresponding events are emitted, *before* the output is executed. Off-chain components such as the Cartesi Rollups Node are unaffected.

- Index application contract event parameters

  `OutputExecuted`, `RefundIssued` and `Withdrawal` now declare their index parameter (`outputIndex`, `inputIndex` and `accountIndex`, respectively) as `indexed`, which changes the event topic layout and allows filtering by index. This adds a negligible gas cost to `executeOutput`, `issueRefund` and `withdraw`.

- Revert output execution when the target account has no code

  - Add the `TargetHasNoCode(address target)` error to the new `AddressErrors` interface, inherited by `IApplication`
  - Raise it from `executeOutput` when a voucher with a non-empty payload or a delegate-call voucher target an account with no code
  - Move the `InsufficientFunds` error from `IApplication` to `AddressErrors` (still reachable through `IApplication`)

  This can indicate a programming error (the back-end emitted an executable output targetting to the wrong address) or an operational one (the target was never deployed to the target network). If the target can still be deployed to the expected address, the application can be fixed on the fly; otherwise, foreclosure is the best alternative.

- Make `foreclose()` revert with `Foreclosed()` if the application has already been foreclosed ([#534](https://github.com/cartesi/rollups-contracts/issues/534))

  As a result, an application emits the `Foreclosure()` event at most once.

- Discontinue npm and Cannon distribution ([#531](https://github.com/cartesi/rollups-contracts/issues/531))

  - Stop publishing the `@cartesi/rollups` package to npmjs.com, and remove `package.json`, the pnpm lockfile and the pnpm/corepack dependency
  - Remove `cannonfile.toml` and all Cannon support
  - Remove the `.changeset` directory; changelogs are now written manually on every release
  - Define the project version in `src/common/Version.sol` (generated from the `Makefile`) instead of in `package.json`
  - The contracts source code remains available through the Soldeer package and its artifacts through GitHub releases

- Restrict the published build artifacts to a curated subset of contracts ([#539](https://github.com/cartesi/rollups-contracts/issues/539))

  The artifacts tarball and the Rust bindings crate now contain only the contracts that clients (`rollups-ts`, `rollups-explorer`, `rollups-node`) are expected to use. Artifacts for dependencies (OpenZeppelin, Machine Solidity Step), test utilities and internal libraries are no longer published. Concrete deployed contracts are included alongside their interfaces so that `rollups-ts` can generate wagmi hooks, but using interfaces is recommended wherever possible.

- Bump the Solidity pragma of all contracts to `^0.8.30`

- Bump Foundry from 1.4.3 to 1.5.1

### Minor Changes

- Add deposit refunds, which let users recover assets from unprocessed deposits after an application is foreclosed ([#512](https://github.com/cartesi/rollups-contracts/issues/512))

  - Add the `RefundOutputBuilder` contract (along with the `IRefundOutputBuilder` and `IRefundOutputBuilderErrors` interfaces), which decodes a deposit input and builds an output transferring the asset back to the original depositor. It is static-called by the application, and supports Ether, ERC-20, ERC-721 and single and batch ERC-1155 deposits made through the canonical portals. It is deployed as a core contract on all supported networks.
  - Add an `issueRefund(uint256 inputIndex, bytes input)` function to `IApplication`, callable by anyone once the application is foreclosed, for inputs that were never finalized. On success it marks the input as refunded, emits a `RefundIssued(uint256 indexed inputIndex, bytes input, bytes output)` event, and executes the refund output.
  - Add `getRefundOutputBuilder`, `getNumberOfIssuedRefunds` and `wasRefundForInputIssued` view functions to `IApplication`
  - Add `validateInput(uint256 inputIndex, bytes input)` and `validateInputHash(uint256 inputIndex, bytes32 inputHash)` view functions to `IApplication`, which check an input against the application's input box and decode it
  - Add the `CannotRefundFinalizedInput`, `RefundAlreadyIssued`, `InvalidInputIndex`, `InvalidInputHash` and `IllFormedInput` errors to `IApplication`, and the `UnknownInputSender` error to `IRefundOutputBuilderErrors` (raised for non-deposit inputs or inputs from non-canonical portals)
  - Add decoding counterparts to `InputEncoding` (`decodeEtherDeposit`, `decodeErc20Deposit`, `decodeErc721Deposit`, `decodeErc1155SingleDeposit`, `decodeErc1155BatchDeposit`) along with the corresponding deposit structs and libraries
  - Document in the portal interfaces that a refund may fail if the depositor is a contract that does not accept the asset back (for example, a smart contract wallet with no `receive` entrypoint, or one that does not implement the ERC-721/ERC-1155 receiver hooks); in that case the funds may not be recoverable

- Support emergency withdrawals even in the absence of accepted claims ([#530](https://github.com/cartesi/rollups-contracts/issues/530))

  In `proveAccountsDriveMerkleRoot`, if the outputs Merkle root validator reports a zeroed last-finalized machine Merkle root, the application's template hash is used instead. This covers the edge case in which the accounts drive is not initially empty.

- Make `Authority` and `Quorum` return `true` from `supportsInterface` for the `IOutputsMerkleRootValidator` interface ID

- Deploy a `UsdWithdrawalOutputBuilder` to devnet ([#532](https://github.com/cartesi/rollups-contracts/issues/532))

  It is deployed through the `UsdWithdrawalOutputBuilderFactory` with `TestFungibleToken` as the backing ERC-20 token, and stored as `TestUsdWithdrawalOutputBuilder` to make it clear that it is devnet-only.

- Add recipient-taking mint and burn entrypoints to the devnet test tokens

  - `TestFungibleToken`: `mint(address to, uint256 value)` and `burn(uint256 value)`, compatible with the `cast erc20 mint` and `cast erc20 burn` commands introduced in Foundry 1.5.0
  - `TestNonFungibleToken`: `mint(address to, uint256 tokenId)`
  - `TestMultiToken`: `mint(address to, uint256 tokenId, uint256 value)` and `mintBatch(address to, uint256[] tokenIds, uint256[] values)`

- Add `test` directory to published Soldeer package

### Patch Changes

- Bump `cartesi-machine-solidity-step` from 0.13.0 to 0.15.0-test1 (a further bump is expected once a definitive 0.15.0 tag is released)
- Bump the Foundry toolchain action from 1.3.1 to 1.8.0
- Refactor the deployment pipeline: replace the Bash scripts with a `Makefile`, add a code-generation Forge script that emits typed contract deployers (`script/utils/ContractDeployers.sol`) and the version constants, add a CI job that checks the generated code is up to date, and set `always_use_create_2_factory` ([#529](https://github.com/cartesi/rollups-contracts/issues/529))
- Reuse the deployment script code in the tests, and drop the `SimpleERC*` helpers in favour of the devnet `Test*Token` contracts ([#528](https://github.com/cartesi/rollups-contracts/issues/528))
- Add `Makefile` targets: `install-foundry`, `check-foundry-version` (a prerequisite of `devnet`, so a state dump is never produced with the wrong Foundry version), `coverage`, `rust-bindings`, `publish-soldeer-package`, `release-artifacts`, `deploy-livenets` and `codegen`
- Build the RPC URL for each chain automatically when the `ALCHEMY_API_KEY` environment variable is set, and rename the networks to match the Alchemy subdomains
- Add the `build` target as a prerequisite of every deployment target, so parallel deployments do not race to fetch the Solidity compiler or rebuild redundantly
- Check that a refund has not already been issued before validating the input, so `issueRefund` reverts earlier in that case
- Check whether an output was already executed before building it, since the execution check has a bounded cost and is more susceptible to race conditions, while output builders behave almost as pure functions
- Annotate the assembly blocks in `LibKeccak256`, `LibError` and `LibAddress` as memory-safe
- Move the helper `ExternalLibBinaryMerkleTree` library out of the test file and rename it `LibBinaryKeccak256MerkleTree`, making the hash function explicit
- Turn on the `fmt.single_line_imports` Foundry option, introduced in Foundry 1.5.0
- Fix the documentation on `LibWithdrawalConfig` ([#509](https://github.com/cartesi/rollups-contracts/issues/509))
- Fix the ERC-20 portal documentation, which claimed a custom error is raised when the token returns an empty or ill-formed value instead of an ABI-encoded boolean; in reality Solidity type-checks it and raises a low-level error
- Fix the deployment documentation on the Ethereum mainnet RPC URL environment variable and Make target
- Fix the README, which described Dave as a future plan even though it has long been implemented and integrated through the `DaveConsensus` contract
- Fix a typo in `ISafeErc20Transfer`, the `Erc1155BatchDeposit` NatSpec, and assorted minor documentation issues
- Remove the unused gas-optimization, smart-contract-audit and update-dependencies issue templates, and drop the `T-*` labels
- Improve test quality and coverage: fuzz application deployment arguments in the factory tests, test ill-formed inputs via a mocked input box, test ERC-1155 batch deposits with zero, one and many token IDs separately, test refunds with ill-formed payloads and reverting ERC-20 transfers, test outputs targeting contracts that reject assets, test re-execution attempts through all three entrypoints, and define custom errors for internal test failures

## 3.0.0-alpha.6

### Minor Changes

- 10c5b00: Make `proveAccountsDriveMerkleRoot` function emit (new) `AccountsDriveMerkleRootProved` event

## 3.0.0-alpha.5

### Major Changes

- d26a08d: Add application contract address parameter to `buildWithdrawalOutput` function
- 077af6f: Make deployment addresses chain-independent

  - Add `UsdWithdrawalOutputBuilderFactory` contract, which deploys `UsdWithdrawalOutputBuilder` contracts for any ERC-20 token
  - Add `UsdWithdrawalOutputBuilderFactory` to Cannonfile and Forge deployment script
  - Remove deployment of `UsdWithdrawalOutputBuilder` with chain-dependent USDC token contract address from Forge deployment script

- b435fb5: Disable app owner privileges (consensus migration) after foreclosure

### Minor Changes

- 077af6f: Add test tokens (`TestFungibleToken`, `TestNonFungibleToken`, and `TestMultiToken`) to Cannonfile (only deployed to devnet)
- dd6b4d5: Distribute deterministic deployment addresses as `rollups-contracts-<version>-deployment-addresses.tar.gz` release artifacts.
  The tarball contains `deployments/<chain-id>/<contract>.json` files for Ethereum, Optimism, Base, and Arbitrum mainnets and their Sepolia testnets.
  Clients should check whether `eth_getCode` (or `cast code`) returns non-empty bytecode at any given address before using it.
  Devnet deployment addresses are still distributed through `rollups-contracts-<version>-anvil-<foundry-version>.tar.gz`.
- a119d23: Add `getWithdrawalConfig` function to `IApplicationWithdrawal`

## 3.0.0-alpha.4

### Major Changes

- e8d46d9: Remove `InvalidAccountIndex` (in favor of already-existing `InvalidNodeIndex` error)
- d7db669: Add `claimStagingPeriod` parameter to functions in the following contracts: `AuthorityFactory`, `SelfHostedApplicationFactory`, and `QuorumFactory`.
  This parameters controls how many base-layer blocks need to elapse before a staged claim can be accepted.
- e8d46d9: Reduce account validity proof size by splitting the validation process into two:
  - First, the accounts drive Merkle root is validated through the new `proveAccountsDriveMerkleRoot` function
  - Second, the account is validated based on the proved accounts drive Merkle root
- c35d26c: Add `appContract` parameter to `getNumberOf{Submitted,Accepted}Claims` functions
- c047ca0: Convert error strings into custom errors
- d7db669: Change the `submitClaim` function to put claims into a staging phase instead of instantly accepting them.

### Minor Changes

- e8d46d9: Add new definitions to `IApplicationWithdrawal` interface:

  - `getAccountsDriveMerkleRoot` view function: checks whether the accounts drive Merkle root was proved, and its value
  - `proveAccountsDriveMerkleRoot` function: proves the accounts drive Merkle root based on the last-finalized machine Merkle root
  - `InvalidAccountsDriveMerkleRootProofSize` error: raised when accounts drive Merkle root proof size is invalid
  - `AccountsDriveMerkleRootAlreadyProved` error: raised when trying to prove accounts drive Merkle root after it has already been proved
  - `AccountsDriveMerkleRootNotProved` error: raised when trying to validate account before accounts drive Merkle root has been proved
  - `InvalidAccountsDriveMerkleRoot` error: raised when account validity proof produces accounts drive Merkle root different from proved one

- 1c87c68: Add `version()` function to all Rollups contracts
- d7db669: Add definitions to `IConsensus` interface:
  - `ClaimStatus` enumeration: unstaged, staged, and accepted
  - `Claim` structure: status, staging block number, and staged outputs Merkle root
  - `ClaimStaged` event: a submitted claim has met the consensus staging criteria
  - `getClaimStagingPeriod` view function: get claim staging period in base-layer blocks
  - `getNumberOfStagedClaims` view function: per-app counter of `ClaimStaged` events
  - `getClaim` view function: claim information getter
  - `acceptClaim` function: accepts staged claims
  - `ClaimNotStaged` error: tried to accept unstaged or already-accepted claim
  - `ClaimStagingPeriodNotOverYet` error: tried to accept claim during its staging period

### Patch Changes

- 4c45da8: Fix Quorum not reverting with `NotFirstClaim` on claim resubmission

## 3.0.0-alpha.3

### Patch Changes

- 8c8ce84: Dry-run release workflows on PRs and pushes to branches

## 3.0.0-alpha.2

### Major Changes

- d9e9104: Add machine Merkle root as parameter to `ClaimSubmitted` and `ClaimAccepted` events
- d9e9104: Add Merkle proof of outputs Merkle root in the machine as parameter to `submitClaim` function
- 7b116d1: Make Quorum deployment revert if validator set is empty or contains the zero address
- a160588: Make `addInput` (and consequently all deposit functions) revert if app was not deployed or is foreclosed
- 7b116d1: Make `submitClaim` function revert if app was not deployed or is foreclosed
- 15a7d01: Add withdrawal configuration parameter to app deployment entrypoints
- d9e9104: Make `Quorum` functions `numOfValidatorsInFavorOf` and `isValidatorInFavorOf` receive machine Merkle root instead of outputs Merkle root

### Minor Changes

- ee27af7: Add functions related to foreclosure to app interface: `isForeclosed`, `getGuardian`, `foreclose`
- 74d225d: Deploy `UsdWithdrawalOutputBuilder` contract (which enables emergency withdrawals for apps backed by USDC) to all supported networks
- d9e9104: Make `Quorum` functions `numOfValidatorsInFavorOf` and `isValidatorInFavorOf` receive machine Merkle root instead of outputs Merkle root
- a18eab1: Deploy test token contracts with built-in faucets (ERC-20 `TestFungibleToken`, ERC-721 `TestNonFungibleToken`, ERC-1155 `TestMultiToken`) to devnet
- 4a40009: Add functions related to accounts drive to app interface: `getLog2LeavesPerAccount`, `getLog2MaxNumOfAccounts`, `getAccountsDriveStartIndex`
- 7a3463b: Add functions related to withdrawals to app interface: `getWithdrawalOutputBuilder`, `withdraw`, `getNumberOfWithdrawals`, `wereAccountFundsWithdrawn`
- 7a95b3b: Add functions related to accounts validation to app interface: `validateAccountMerkleRoot`, `validateAccount`

## 2.2.1-alpha.1

### Patch Changes

- fe5ceca: Set `GH_TOKEN` env. var when running `gh` on the CI

## 2.2.1-alpha.0

### Patch Changes

- a887f66: Use GH CLI to upload assets to GH releases

## 2.2.0

### Minor Changes

- 54d2d1c: Added `getNumberOfSubmittedClaims` view function to `IConsensus` interface

## 2.1.1

### Patch Changes

- dee9d7c: Fix deployment Forge script
- 70a43e0: Make devnet build not require Cannon or Node.js
- 826473b: Improve deployment Forge script

  - Store deployments in directories indexed by chain
  - Create abstract deployment script contract for code reuse
  - Make script idempotent (skips deployment when address has code)
  - Implement loading deployment functionality (to be used in dave repo)

- 4e448cd: Fix devnet build (preserve historical states)
- 05ecd57: Add deployment script and guide

## 2.1.1-alpha.4

### Patch Changes

- 05ecd57: Add deployment script and guide

## 2.1.1-alpha.3

### Patch Changes

- 826473b: Improve deployment Forge script

  - Store deployments in directories indexed by chain
  - Create abstract deployment script contract for code reuse
  - Make script idempotent (skips deployment when address has code)
  - Implement loading deployment functionality (to be used in dave repo)

## 2.1.1-alpha.2

### Patch Changes

- dee9d7c: Fix deployment Forge script

## 2.1.1-alpha.1

### Patch Changes

- 70a43e0: Make devnet build not require Cannon or Node.js

## 2.1.1-alpha.0

### Patch Changes

- 4e448cd: Fix devnet build (preserve historical states)

## 2.1.0

### Minor Changes

- 335414a:
  - Add `getNumberOfExecutedOutputs()` view function to **IApplication** interface and implementation.
  - Add `getNumberOfAcceptedClaims()` view function to **IConsensus** interface and implementations.

### Patch Changes

- 85190ad: Bump foundry from 1.1.0 to 1.4.3
- 363ca77: Use API token when publishing to Soldeer
- 4604760: Use the zero hash as salt for all `CREATE2` deployments
- b36152b: Bump solc from 0.8.29 to 0.8.30
- 1eaf7e1: Bump `@changesets/cli` from 2.22.0 to 2.29.7
- 949e2d1: Bump target EVM version from cancun to prague

## 2.1.0-alpha.3

### Patch Changes

- 363ca77: Use API token when publishing to Soldeer

## 2.1.0-alpha.2

### Patch Changes

- 85190ad: Bump foundry from 1.4.2 to 1.4.3

## 2.1.0-alpha.1

### Patch Changes

- 1eaf7e1: Bump `@usecannon/cli` from 2.22.0 to 2.25.0
- 4604760: Use the zero hash as salt for all `CREATE2` deployments
- fab54a1: Bump foundry from 1.1.0 to 1.4.2
- b36152b: Bump solc from 0.8.29 to 0.8.30
- 1eaf7e1: Bump `@changesets/cli` from 2.29.4 to 2.29.7
- 949e2d1: Bump target EVM version from cancun to prague

## 2.1.0-alpha.0

### Minor Changes

- 335414a:
  - Add `getNumberOfExecutedOutputs()` view function to **IApplication** interface and implementation.
  - Add `getNumberOfAcceptedClaims()` view function to **IConsensus** interface and implementations.

## 2.0.1

### Patch Changes

- 84cb34e: Add dotfiles to `.soldeerignore`

## 2.0.1-alpha.0

### Patch Changes

- 84cb34e: Add dotfiles to `.soldeerignore`

## 2.0.0

### Additions

#### Applications

- Added a `getDeploymentBlockNumber` function to the `IApplication` interface, for improved event listening
- Added a `getDataAvailability` function to the `IApplication` interface

#### Inputs

- Added the application contract address as input metadata
- Added the base layer chain ID as input metadata
- Added the [EIP-4399](https://eips.ethereum.org/EIPS/eip-4399) `PREVRANDAO` value as input metadata
- Added an `InputTooLarge` error to the `IInputBox` interface

#### Outputs

- Added an `Outputs` interface with the signatures of all canonical output types (notices, `CALL` vouchers, and `DELEGATECALL` vouchers)
- Added a `value` field to `CALL` vouchers, to encode the amount of Wei transferred through the message call
- Added a new type of executable output: `DELEGATECALL` vouchers
- Added an `executeOutput` function to the `IApplication` interface
- Added a `wasOutputExecuted` function to the `IApplication` interface
- Added a `validateOutput` function to the `IApplication` interface
- Added a `validateOutputHash` function to the `IApplication` interface
- Added an `OutputExecuted` event to the `IApplication` interface
- Added an `OutputNotExecutable` error to the `IApplication` interface, for when trying to execute a notice, for example
- Added an `OutputNotReexecutable` error to the `IApplication` interface, for when trying to re-execute a voucher, for example
- Added an `InsufficientFunds` error to the `IApplication` interface, for when trying to execute a voucher with more value than the contract balance
- Added an `InvalidOutputHashesSiblingsArrayLength` error to the `IApplication` interface, for when providing a siblings array with invalid length
- Added an `InvalidOutputsMerkleRoot` error to the `IApplication` interface, when the outputs Merkle root derived from the validity proof is invalid
- Added an `IOutputsMerkleRootValidator` interface, to substitute `IConsensus` in the `IApplication` interface
- Added a `SafeERC20Transfer` contract to be called via `DELEGATECALL` vouchers to safely transfer ERC-20 tokens (by checking whether `transferFrom` returns `true`)
- Added a `LibAddress` library for safely calling and delegating calls to foreign contracts
- Added a `LibError` library for raising byte arrays as errors
- Added a `LibMerkle32` library for verifying Merkle proofs with 32-byte leaves

#### Portals

- Added an `EtherTransferFailed` error to the `IEtherPortal` interface
- Added an `ERC20TransferFailed` error to the `IERC20Portal` interface

#### Consensus

- Added a `submitClaim(address,uint256,bytes32)` function to the `IConsensus` interface
- Added a `getEpochLength` function to the `IConsensus` interface
- Added a `ClaimSubmitted` event to the `IConsensus` interface
- Added a `ClaimAccepted` event to the `IConsensus` interface
- Added a `NotEpochFinalBlock` event to the `IConsensus` interface, for when trying to submit a claim with a last processed block that is not at the end of an epoch
- Added a `NotPastBlock` event to the `IConsensus` interface, for when trying to submit a claim with a last processed block that is not in the past
- Added a `NotFirstClaim` event to the `IConsensus` interface, for when trying to submit two claims for the same epoch
- Added an `IQuorum` interface (which inherits from the `IConsensus` interface)
- Added an `IQuorumFactory` interface for instantiating contracts that implement the `IQuorum` interface
- Added a `Quorum` contract (which implements the `IQuorum` interface)
- Added a `QuorumFactory` contract (which implements the `IQuorumFactory` by instantiating `Quorum` contracts)

#### Others

- Added a `getDeploymentBlockNumber` function to the `IInputBox` interface, for improved event listening
- Added an `IOwnable` interface with functions from OpenZeppelin's `Ownable` abstract contract
- Added a Cannonfile to describe the deployment of all singletons (`InputBox`, portals, factories, and `SafeERC20Transfer`)
- Added a workflow to publish the contracts source code to [Soldeer](https://soldeer.xyz/), a package manager for Solidity dependencies

### Changes

#### Applications

- Renamed `CartesiDApp` as `Application`
- Renamed `ICartesiDApp` as `IApplication`
- Renamed `CartesiDAppFactory` as `ApplicationFactory`
- Renamed `ICartesiDAppFactory` as `IApplicationFactory`

#### Inputs

- Changed the semantics of the `input` parameter of the `InputAdded` event to encode both payload and metadata
- Changed the semantics of the `getInputHash` function of the `IInputBox` interface to be the hash of the input blob (which encodes both payload and metadata)
- Changed the input size limit from 2097088 bytes (~2 MB) to 64 KB to ensure inputs can be merkelized later during [Dave](https://github.com/cartesi/dave) PRT disputes

#### Outputs

- Changed the `OutputValidityProof` struct to contain just the output index and the output hashes siblings array
- Changed the `executeOutput` function (former `executeVoucher`) to propagate errors raised by executable outputs (which includes vouchers)

#### Portals and Relays

- Changed the ERC-20 portal to only add deposit inputs if the transfers are successful (that is, when `transferFrom` returns `true`), removing the need for the `success` field
- Renamed `InputRelay` as `Portal`
- Renamed `IInputRelay` as `IPortal`

#### Consensus

- Changed the `IConsensus` interface to inherit from the `IOutputsMerkleRootValidator` and ERC-165 interface

#### Others

- Changed the Node.js package manager used in the repository from `yarn` to `pnpm`
- Changed the tool to deploy the smart contracts from `hardhat-deploy` to [Cannon](https://usecannon.com/)
- Changed the package manager used to manage Solidity dependencies from Node.js to [Soldeer](https://soldeer.xyz/)

### Removals

#### Inputs

- Removed the `sender` parameter from the `InputAdded` event (the sender address is now encoded in the input)
- Removed the `InputSizeExceedsLimit` error in favor of the `InputTooLarge` error

#### Outputs

- Removed the `executeVoucher` function in favor of the more generic `executeOutput` function
- Removed the `validateNotice` function in favor of the more generic `validateOutput` and `validateOutputHash` functions
- Removed the Boolean return value from the `executeOutput` (former `executeVoucher`) and `validateOutput` (former `validateNotice`) functions
- Removed the `VoucherExecuted` event in favor of the more generic `OutputExecuted` event
- Removed the `voucherId` parameter from the `OutputExecuted` event (former `VoucherExecuted`) in favor of the more genreric `outputIndex` parameter
- Removed the `wasVoucherExecuted` event in favor of the more generic `wasOutputExecuted` function
- Removed the `withdrawEther` function from `Application` in favor of vouchers with the `value` field set to the desired amount of Wei to be withdrawn
- Removed the `OnlyApplication` error from `Application` as it was only used by the `withdrawEther` function
- Removed the `EtherTransferFailed` error from `Application` as it was only used by the `withdrawEther` function

#### Portals and Relays

- Removed the `success` field from the ERC-20 deposit input because all ERC-20 deposit inputs are now successful
- Removed the `DAppAddressRelay` contract in favor of the application contract address field added as input metadata
- Removed the `IDAppAddressRelay` interface

#### Consensus

- Removed the `join` function from the `IConsensus` interface
- Removed the `getClaim` function from the `IConsensus` interface in favor of the `isOutputsMerkleRootValid` function from the `IOutputsMerkleRootValidator` interface
- Removed the `ApplicationJoined` event from the `IConsensus` interface
- Removed the `submitClaim(bytes)` function from the `IConsensus` interface in favor of the `submitClaim(address,uint256,bytes32)` function
- Removed `authorityOwner` parameter from `AuthorityCreated` event
- Removed the `AuthorityWithdrawalFailed` error from the `Authority` contract
- Removed the `NewHistory` event from the `Authority` contract
- Removed the `getHistory` function from the `Authority` contract
- Removed the `migrateHistoryToConsensus` function from the `Authority` contract
- Removed the `setHistory` function from the `Authority` contract
- Removed the `withdrawERC20Tokens` function from the `Authority` contract

#### History

- Removed the `History` contract
- Removed the `IHistory` interface
- Removed the `HistoryFactory` contract
- Removed the `IHistoryFactory` interface
- Removed the `AuthorityHistoryPairFactory` contract
- Removed the `IAuthorityHistoryPairFactory` interface
- Removed the `getAuthorityHistoryPairFactory` function from the `ISelfHostedApplicationFactory` interface

### Dependency bumps

- Bumped [Solidity](https://soliditylang.org/) from 0.8.19 to 0.8.29
- Bumped [OpenZeppelin contracts](https://github.com/OpenZeppelin/openzeppelin-contracts) from 4.9.2 to 5.2.0
- Bumped [Foundry](https://book.getfoundry.sh/) from nightly builds to 1.1.0
- Bumped [Node.js](https://nodejs.org/en) from 18 to 22
- Bumped [Alloy](https://alloy.rs/) from 0.3.1 to 0.12.4

## 2.0.0-rc.18

### Major Changes

- 263543d: Avoid conflicting claims in Quorum

### Minor Changes

- 6e893a7: Make `Authority` and `Quorum` validate last processed block number

### Patch Changes

- 101bc7a: Bump solc from 0.8.23 to 0.8.29

## 2.0.0-rc.17

### Major Changes

- bc0558f: Rename events:

  - `ClaimAcceptance` -> `ClaimAccepted`

  - `ClaimSubmission` -> `ClaimSubmitted`

  - `NewOutputsMerkleRootValidator` -> `OutputsMerkleRootValidatorChanged`

### Minor Changes

- 5e19b4b: Add `getDeploymentBlockNumber` function to `IApplication` interface

### Patch Changes

- 8fe54d7: Fix workflow that publishes Rust bindings

## 2.0.0-rc.16

### Minor Changes

- 597dc74: Add Cannonfile

## 2.0.0-rc.15

### Major Changes

- c265308: Make `IConsensus` implement ERC-165

### Patch Changes

- c265308: Use stable release of Foundry

## 2.0.0-rc.14

### Minor Changes

- 9f940da: Add data availability configuration to application contract

## 2.0.0-rc.13

### Patch Changes

- 910acbb: Bump alloy to 0.8.0

## 2.0.0-rc.12

### Patch Changes

- 68673bd: Restore transaction receipts from Ethereum Sepolia deployment

## 2.0.0-rc.11

### Major Changes

- 32ee7d7: Raise an error if voucher has more value than the contract has balance

## 2.0.0-rc.10

### Major Changes

- 9e515d4: Make `IAuthorityFactory` functions return `IAuthority`
- 9e515d4: Made `ISelfHostedApplicationFactory` return `IApplication`
- 3ef8cb5: Make `IQuorumFactory` functions return `IQuorum`

### Minor Changes

- b7d6477: Add `IOwnable` interface
- d425fe1: Add `IQuorum` interface
- e1bcf0d: Add `IAuthority` interface

## 2.0.0-rc.9

### Patch Changes

- 4f28ef9: Bump alloy to 0.3.1 for Rust bindings

## 2.0.0-rc.8

### Patch Changes

- 25da049: Fix alloy dependency in Cargo.toml

## 2.0.0-rc.7

### Patch Changes

- 56a8d11: Generate Alloy bindings in the CI

## 2.0.0-rc.6

### Major Changes

- f8c25e9: Added a `lastProcessedBlockNumber` parameter to `IConsensus` functions and events.
- 3d40890: Removed `authorityOwner` parameter from `AuthorityCreated` event.
- 7f27379: Added an `epochLength` parameter to functions of:

  - `IAuthorityFactory`
  - `ISelfHostedApplicationFactory`
  - `IQuorumFactory`

### Minor Changes

- 7f27379: Added a `getEpochLength` function to `IConsensus` interface.

## 2.0.0-rc.5

### Major Changes

- 5b46210: Add `validateOutputHash` function to `IApplication`
- 5b46210: Removed `InputRange` struct
- 5b46210: Refactored `IConsensus`

  - Removed `InputRange` from functions and events
  - Claim is now output hashes root hash
  - Replaced `getEpochHash` with `wasClaimAccepted`

- 5b46210: Updated `wasOutputExecuted` function signature

  - Removed `inputIndex` parameter
  - Renamed `outputIndexWithinInput` as `outputIndex`

- 5b46210: Remove functions `getInputBox` and `getPortals` from `IApplication`
- 5b46210: Removed parameters from `Application` contracts

  - `IInputBox` (not used)
  - `IPortals[]` (wasted gas on `SSTORE`, not used)

- 5b46210: Removed support to ERC-165 (not used)
- 5b46210: Remove `IInputBox` and `IPortal[]` parameters from `IApplicationFactory` and `ISelfHostedApplicationFactory` functions and events
- 5b46210: Completely restructured `OutputValidityProof`

  - Removed all fields
  - Added `outputIndex`
  - Added `outputHashesSiblings`

## 2.0.0-rc.4

### Major Changes

- 446d05a: Add the following fields as the input metadata:

  - The application contract address
  - The chain ID
  - The latest RANDAO mix of the post beacon state of the previous block

- eee5e13: Removed ENS-related contracts

### Minor Changes

- eee5e13: Deploy contracts to Ethereum Sepolia
- eee5e13: Add `SafeERC20Transfer` to deploy script
- eee5e13: Add `QuorumFactory` to deploy script

## 2.0.0-rc.3

### Major Changes

- 472eb80: Added contract `AssetTransferToENS` that can be used as a destination for `DELEGATECALL` vouchers to transfer assets to ENS-identified accounts.
  Added library `LibAddress` for safe low level call and safe delegate call.
- cae579d: Added ENS Portal.
  Added a new input encoding for ENS inputs.

### Minor Changes

- 5559379: Add a contract for safe ERC20 transfers. This can be used by delegatecall vouchers.
- d4c1164: Add self-hosted application factory contract
- 8e958f2: Supported the execution of `DELEGATECALL` vouchers

## 2.0.0-rc.2

### Major Changes

- 91d1c115: Remove `EvmInspect` function

### Minor Changes

- 91d1c115: Rename parameters of `EvmAdvance` function

## 2.0.0-rc.1

### Patch Changes

- f29b098b: Adjusted the GitHub Action that publishes the Rust bindings to crates.io.

  - Initialize git submodules recursively
  - Install the foundry toolkit

## 2.0.0-rc.0

### Major Changes

- d8561fe3: Modified the `OutputValidityProof` struct:

  - Collapsed the `vouchersEpochRootHash` and `noticesEpochRootHash` fields into a single `outputsEpochRootHash` field
  - Added an `inputRange` field

- d8561fe3: Modified the ERC-20 deposit input:

  - Removed the `success` field, because the ERC-20 portal now only adds inputs for successful deposits.

- d8561fe3: Modified the `CanonicalMachine` library:

  - Collapsed the `VOUCHER_METADATA_LOG2_SIZE` and `NOTICE_METADATA_LOG2_SIZE` constants into a single `OUTPUT_METADATA_LOG2_SIZE` constant (with the same value).
  - Collapsed the `EPOCH_VOUCHER_LOG2_SIZE` and `EPOCH_NOTICE_LOG2_SIZE` constants into a single `EPOCH_OUTPUT_LOG2_SIZE` constant (with the same value).
  - Updated the value of the `INPUT_MAX_SIZE` constant to reflect a change in the off-chain machine.

- d8561fe3: Modified the `EtherPortal` contract:

  - Made it support the following interfaces (as in EIP-165):

    - `IERC165`
    - `IInputRelay`
    - `IEtherPortal`

- d8561fe3: Modified the `AbstractConsensus` contract:

  - Removed the `join` function
  - Implemented the `getEpochHash` function
  - Added an internal `_acceptClaim` function

- 13eb18a4: Inputs are now blockchain-agnostic and self-contained blobs.
- 4e2533ef: Include application address in `EvmAdvance` input.
- d8561fe3: Modified the `IInputRelay` interface:

  - Made it inherit from `IERC165`

- d8561fe3: Modified the `ERC1155BatchPortal` contract:

  - Made it support the following interfaces (as in EIP-165):

    - `IERC165`
    - `IInputRelay`
    - `IERC1155BatchPortal`

- d8561fe3: Modified the `IEtherPortal` interface:

  - Added an `EtherTransferFailed` error.

- d8561fe3: Bumped `@openzeppelin/contracts` from `4.9.2` to `5.0.0`.
- d8561fe3: Moved `Proof` to a dedicated file in the `common` directory.
- f39e4ef0: Added a `value` field to vouchers.
- d8561fe3: Moved `OutputValidityProof` to a dedicated file in the `common` directory.
- d8561fe3: Modified the `ICartesiDAppFactory` interface:

  - Renamed it as `IApplicationFactory`.
  - Added the following parameters to its functions and events:

    - `inputBox`
    - `inputRelays`

- d8561fe3: Modified the `CartesiDApp` contract:

  - Renamed it as `Application`.
  - Added the following parameters to its constructor:

    - `inputBox`
    - `inputRelays`

  - Made it support the following interfaces (as in EIP-165):

    - `IApplication`
    - `IERC721Receiver`

  - Removed the `withdrawEther` function.
  - Removed the `OnlyApplication` error.
  - Removed the `EtherTransferFailed` error.

- d8561fe3: Modified the `ERC1155SinglePortal` contract:

  - Made it support the following interfaces (as in EIP-165):

    - `IERC165`
    - `IInputRelay`
    - `IERC1155SinglePortal`

- d8561fe3: Removed:

  - the `History` contract.
  - the `IHistory` interface.
  - the `HistoryFactory` contract.
  - the `IHistoryFactory` interface.
  - the `AuthorityHistoryPairFactory` contract.
  - the `IAuthorityHistoryPairFactory` interface.
  - the `OutputEncoding` library.
  - the `LibInput` library.
  - the `ApplicationAddressRelay` contract.
  - the `IApplicationAddressRelay` interface.

- 8892a88b: Include chain ID in `EvmAdvance` input.
- d8561fe3: Modified the `ICartesiDApp` interface:

  - Renamed it as `IApplication`.
  - Made it inherit from:

    - `IERC721Receiver`.
    - `IERC1155Receiver` (which inherits from `IERC165`).

  - Modified the `executeVoucher` function:

    - Renamed it as `executeOutput`.
    - Errors raised by low-level calls are bubbled up.
    - Changed the type of the `proof` parameter to `OutputValidityProof`.
    - Removed the boolean return value.

  - Modified the `validateNotice` function:

    - Renamed it as `validateOutput`.
    - Changed type of the `proof` parameter to `OutputValidityProof`.
    - Removed the boolean return value.

  - Modified the `VoucherExecuted` event:

    - Renamed it as `OutputExecuted`.
    - Split the `voucherId` parameter into `inputIndex` and `outputIndexWithinInput` parameters.
    - Added an `output` parameter.

  - Modified the `wasVoucherExecuted` function:

    - Renamed it as `wasOutputExecuted`.

  - Added a `getInputBox` function.
  - Added a `getInputRelays` function.
  - Added an `InputIndexOutOfRange` error.
  - Added an `OutputNotExecutable` error.
  - Added an `OutputNotReexecutable` error.
  - Added an `IncorrectEpochHash` error.
  - Added an `IncorrectOutputsEpochRootHash` error.
  - Added an `IncorrectOutputHashesRootHash` error.

- 13eb18a4: Modified the `IInputBox` interface:

  - Modified the `InputAdded` event:

    - Removed the `sender` parameter.
    - Changed the semantics of the `input` parameter.

  - Added an `InputTooLarge` error.

- d8561fe3: Modified the `CartesiDAppFactory` contract:

  - Renamed it as `ApplicationFactory`.

- d8561fe3: Modified the `InputRelay` contract:

  - Made it support the following interfaces (as in EIP-165):

    - `IERC165`
    - `IInputRelay`

- d8561fe3: Modified the `Authority` contract:

  - Removed the `AuthorityWithdrawalFailed` error
  - Removed the `NewHistory` event
  - Removed the `getClaim` function
  - Removed the `getHistory` function
  - Removed the `join` function
  - Removed the `migrateHistoryToConsensus` function
  - Removed the `setHistory` function
  - Removed the `submitClaim(bytes)` function
  - Removed the `withdrawERC20Tokens` function
  - Implemented the `submitClaim(address,(uint64,uint64),bytes32)` function

- d8561fe3: Completely modified the `IConsensus` interface:

  - Removed the `join` function
  - Removed the `getClaim` function
  - Removed the `ApplicationJoined` event
  - Added a `submitClaim` function
  - Added a `getEpochHash` function
  - Added a `ClaimSubmission` event
  - Added a `ClaimAcceptance` event

- d8561fe3: Bumped the Solidity compiler from `0.8.19` to `0.8.23`.
- d8561fe3: Modified the `IERC20Portal` interface:

  - Added an `ERC20TransferFailed` error.

- d8561fe3: Modified the `ERC20Portal` contract:

  - Made it support the following interfaces (as in EIP-165):

    - `IERC165`
    - `IInputRelay`
    - `IERC20Portal`

- d8561fe3: Removed deployments to Goerli testnets (L1 and L2s).
- d8561fe3: Modified the `ERC721Portal` contract:

  - Made it support the following interfaces (as in EIP-165):

    - `IERC165`
    - `IInputRelay`
    - `IERC721Portal`

### Minor Changes

- d8561fe3: Added:

  - an `Outputs` interface
  - an `InputRange` struct
  - a `LibInputRange` library
  - a `Quorum` contract (which implements the `IConsensus` interface)
  - a `QuorumFactory` contract
  - an `IQuorumFactory` interface

## 1.2.0

### Minor Changes

- 321e29a: Support deployment to `arbitrum_sepolia` and `optimism_sepolia` networks.
- 618121e: Bumped `@cartesi/util` from 6.0.0 to 6.1.0.

## 1.1.0

### Minor Changes

- `AuthorityFactory`: Allows anyone to deploy `Authority` contracts. Supports deterministic deployment.
- `HistoryFactory`: Allows anyone to deploy `History` contracts. Supports deterministic deployment.
- `AuthorityHistoryPairFactory`: Allows anyone to deploy `Authority` and `History` contract pairs (such that `History` is owned by `Authority`, and `Authority` stores/retrieves claims from `History`). Supports deterministic deployment.
- `Authority`: Removed deployment files and script.
- `History`: Removed deployment files and script.

## 1.0.0

### Major Changes

- Added `InvalidClaimIndex` error in `History` contract
- Made portals and relays inherit `InputRelay`
- Renamed `inboxInputIndex` to `inputIndex` in contracts
- Deployed contracts deterministically with `CREATE2` factory
- Renamed fields in `OutputValidityProof` structure
- Updated `@cartesi/util` to 6.0.0
- Removed base portal and relay contracts and interfaces
- Removed `ConsensusCreated` event from `Authority` contract
- Removed `IInputBox` parameter from `Authority` constructor
- Fixed input size limit in `InputBox` contract

### Minor Changes

- Added input relay interface and base contract
- Deployed ERC-1155 portals
- Added `RPC_URL` environment variable during deployment
- Started using custom errors in contracts

### Patch Changes

- Improved proof generation system for on-chain tests

## 0.9.0

### Major Changes

- Simplified the on-chain architecture (not backwards-compatible)
- `CartesiDApp` does not implement [EIP-2535](https://eips.ethereum.org/EIPS/eip-2535) anymore
- Made each Portal a contract of their own, and shared amongst all the DApps
- Made inputs added by Portals more compact by using the [packed ABI encoding](https://docs.soliditylang.org/en/latest/abi-spec.html#non-standard-packed-mode) instead of the standard one
- Made ERC-20 deposits more generic by allowing base layer transfers to fail, and adding a boolean field signaling whether it was successful or not
- Made ERC-721 deposits more generic by adding an arbitrary data field to be interpreted by the off-chain machine in the execution layer
- Moved the input boxes of every DApp into a single, permissionless contract
- Input boxes are now append-only—they are not cleared every new epoch (old Input Facet)
- Modularized the consensus layer (a DApp can now seamlessly change its consensus model)
- Modularized the claim storage layer (a consensus can now seamlessly change how it stores claims)
- Voucher bitmask position is now determined by the input index (in the input box) and output index
- Validators need now to specify the range of inputs of each claim they submit on-chain
- Removed Setup Input
- Removed Quorum consensus model implementation (up to 8 validators)
- Removed Bank contract
- Removed DApp configuration parameters related to the off-chain machine specs (now defined as constants)
- Removed `epochIndex` field from `OutputValidityProof` struct
- Removed headers from inputs added by trusted permissionless contracts like portals and relayers

### Minor Changes

- Added Authority consensus model implementation (single validator)
- Added Simple claim storage implementation (one claim per DApp)
- Added Library that defines several constants related to the canonical off-chain machine
- DApp Address Relay contract (allows the off-chain machine to know the DApp's address)

### Patch Changes

- Added script for updating proofs used in unit tests
- Adopted [Foundry](https://book.getfoundry.sh/) for contract testing (Hardhat is still being used for deployment)

## 0.7.0

### Major Changes

- Documentation updates

## 0.6.0

### Minor Changes

- Deploy to Arbitrum Goerli and Optimism Goerli

## 0.5.0

### Major Changes

- Add `validateNotice` function to OutputFacet

## 0.3.0

### Major Changes

- Moved logic from `erc721Deposit` function to `onERC721Received`
- Renamed `ERC721Deposited` event to `ERC721Received` and added `operator` field
- Validators who lost a dispute are removed from the validator set, and cannot redeem fees from previous claims
- Changed the visibility of `Bank`'s state variables to private
- Changed the visibility of `LibClaimsMask`'s functions to internal
- Removed `erc721Deposit` function (call `safeTransferFrom` from the ERC-721 contract instead)
- Removed `erc20Withdrawal` function call (vouchers now call `transfer` from the ERC-20 contract directly instead)
- Gas optimizations

### Minor Changes

- Add factory contract to deploy rollups diamond

### Patch Changes

- Mermaid diagram of the on-chain rollups on README

## 0.2.0

### Major Changes

- Bumped solc version to 0.8.13
- Updated architecture to Diamonds design pattern
- Added `FeeManagerFacet` and `Bank` contracts
- Template Hash
- Setup Input
- NFT Portal
- Removed Specific ERC-20 Portal

## 0.1.0

First release.
