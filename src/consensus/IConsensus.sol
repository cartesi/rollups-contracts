// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IVersionGetter} from "../common/IVersionGetter.sol";
import {IApplicationChecker} from "../dapp/IApplicationChecker.sol";
import {IOutputsMerkleRootValidator} from "./IOutputsMerkleRootValidator.sol";

/// @notice This interface defines functions for submitting and accepting claims about
/// the state of multiple Cartesi Rollups applications with a single fixed epoch length.
///
/// Each application has its own stream of inputs, which is split into epochs. The index
/// of the epoch of an input is determined by the integer division of the number of the
/// base-layer block in which the input was added by the epoch length (see
/// `getEpochLength` function).
///
/// After every epoch, each validator can submit a claim about the post-epoch state of
/// the application (summarized by a machine Merkle root), while also proving the set of
/// all outputs ever emitted by the application up until that point (summarized by an
/// outputs Merkle root, which is written at a known address in the machine memory, and
/// proved on-chain through a Merkle proof). Naturally, some epochs might be empty (i.e.
/// they contain no input), in which case the state of the application remains unchanged.
/// Validators can save on base-layer fees by not submitting claims for empty epochs.
///
/// If a claim meets the staging criteria of the consensus model, the claim is staged.
/// The criteria for a claim to be staged is outside the scope of this interface, but
/// for example, a claim may be staged if it was...
///
/// - submitted by an authority or;
/// - submitted by the majority of a quorum or;
/// - submitted and not proven wrong after some period of time or;
/// - submitted and proven correct through an on-chain tournament.
///
/// When a claim is staged, its effects are not instant. Validators must wait for the
/// claim staging period (see `getClaimStagingPeriod` function) to elapse before it can
/// be accepted by the consensus. This delay serves as a layer of protection against
/// malicious validators, private-key leakage, smart-contract bugs, and other issues.
/// If a malicious claim is ever staged, the application guardian should have enough time
/// to foreclose the application, preventing the claim from ever being accepted, and
/// allowing users to withdraw their funds from the last-finalized machine Merkle root.
///
/// If the claim staging period is elapsed, and the application was not foreclosed, the
/// claim can be finally accepted, and any outputs generated during that epoch can now be
/// validated on-chain.
///
interface IConsensus is IOutputsMerkleRootValidator, IApplicationChecker, IVersionGetter {
    /// @notice The status of a claim.
    /// @param UNSTAGED The claim was neither staged nor accepted
    /// @param STAGED The claim was staged but not accepted
    /// @param ACCEPTED The claim was staged and accepted
    enum ClaimStatus {
        UNSTAGED,
        STAGED,
        ACCEPTED
    }

    /// @notice Information about a claim.
    /// @param status The status of the claim
    /// @param stagingBlockNumber The number of the block in which the claim was staged
    /// @param stagedOutputsMerkleRoot The outputs Merkle root that was proven on staging
    /// @dev The values of the fields `stagingBlockNumber` and `stagedOutputsMerkleRoot`
    /// only have meaning if the claim was staged. Otherwise, they are meaningless.
    struct Claim {
        ClaimStatus status;
        uint256 stagingBlockNumber;
        bytes32 stagedOutputsMerkleRoot;
    }

    /// @notice MUST trigger when a claim is submitted.
    /// @param submitter The submitter address
    /// @param appContract The application contract address
    /// @param lastProcessedBlockNumber The number of the last processed block
    /// @param outputsMerkleRoot The outputs Merkle root
    /// @param machineMerkleRoot The machine Merkle root
    event ClaimSubmitted(
        address indexed submitter,
        address indexed appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 outputsMerkleRoot,
        bytes32 machineMerkleRoot
    );

    /// @notice MUST trigger when a claim is staged.
    /// @param appContract The application contract address
    /// @param lastProcessedBlockNumber The number of the last processed block
    /// @param outputsMerkleRoot The outputs Merkle root
    /// @param machineMerkleRoot The machine Merkle root
    /// @dev For each application and lastProcessedBlockNumber,
    /// there can be at most one staged claim.
    event ClaimStaged(
        address indexed appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 outputsMerkleRoot,
        bytes32 machineMerkleRoot
    );

    /// @notice MUST trigger when a claim is accepted.
    /// @param appContract The application contract address
    /// @param lastProcessedBlockNumber The number of the last processed block
    /// @param outputsMerkleRoot The outputs Merkle root
    /// @param machineMerkleRoot The machine Merkle root
    /// @dev For each application and lastProcessedBlockNumber,
    /// there can be at most one accepted claim.
    event ClaimAccepted(
        address indexed appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 outputsMerkleRoot,
        bytes32 machineMerkleRoot
    );

    /// @notice The claim contains the number of a block that is not
    /// at the end of an epoch (its modulo epoch length is not epoch length - 1).
    /// @param lastProcessedBlockNumber The number of the last processed block
    /// @param epochLength The epoch length
    error NotEpochFinalBlock(uint256 lastProcessedBlockNumber, uint256 epochLength);

    /// @notice The claim contains the number of a block in the future
    /// (it is greater or equal to the current block number).
    /// @param lastProcessedBlockNumber The number of the last processed block
    /// @param currentBlockNumber The number of the current block
    error NotPastBlock(uint256 lastProcessedBlockNumber, uint256 currentBlockNumber);

    /// @notice A claim for that application and epoch was already submitted by the validator.
    /// @param appContract The application contract address
    /// @param lastProcessedBlockNumber The number of the last processed block
    error NotFirstClaim(address appContract, uint256 lastProcessedBlockNumber);

    /// @notice The claim was not staged and therefore cannot be accepted.
    /// @param appContract The application contract address
    /// @param lastProcessedBlockNumber The number of the last processed block
    /// @param machineMerkleRoot The machine Merkle root
    /// @param claimStatus The status of the claim
    error ClaimNotStaged(
        address appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 machineMerkleRoot,
        ClaimStatus claimStatus
    );

    /// @notice The claim was staged but its staging period is not over yet.
    /// @param appContract The application contract address
    /// @param lastProcessedBlockNumber The number of the last processed block
    /// @param machineMerkleRoot The machine Merkle root
    /// @param numberOfBlocksAfterStaging The number of blocks since the claim was staged
    /// @param claimStagingPeriod The claim staging period, in number of blocks
    error ClaimStagingPeriodNotOverYet(
        address appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 machineMerkleRoot,
        uint256 numberOfBlocksAfterStaging,
        uint256 claimStagingPeriod
    );

    /// @notice Supplied output tree proof size is incorrect
    /// @param suppliedProofSize Supplied proof size
    /// @param expectedProofSize Expected proof size
    error InvalidOutputsMerkleRootProofSize(
        uint256 suppliedProofSize, uint256 expectedProofSize
    );

    /// @notice Submit a claim to the consensus.
    /// @param appContract The application contract address
    /// @param lastProcessedBlockNumber The number of the last processed block
    /// @param outputsMerkleRoot The outputs Merkle root
    /// @param proof The bottom-up Merkle proof of the outputs Merkle root at the start of the machine TX buffer
    /// @dev MUST fire a `ClaimSubmitted` event.
    /// @dev MAY fire a `ClaimStaged` event, if the staging criteria is met.
    function submitClaim(
        address appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 outputsMerkleRoot,
        bytes32[] calldata proof
    ) external;

    /// @notice Accept a staged claim whose staging period has elapsed.
    /// @param appContract The application contract address
    /// @param lastProcessedBlockNumber The number of the last processed block
    /// @param machineMerkleRoot The machine Merkle root
    /// @dev MUST fire a `ClaimAccepted` event.
    function acceptClaim(
        address appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 machineMerkleRoot
    ) external;

    /// @notice Get the epoch length, in number of base-layer blocks.
    /// @dev The epoch number of a block is defined as
    /// the integer division of the block number by the epoch length.
    function getEpochLength() external view returns (uint256);

    /// @notice Get the number of base-layer blocks
    /// after which a staged claim can be accepted.
    function getClaimStagingPeriod() external view returns (uint256);

    /// @notice Get the number of claims accepted by the consensus
    /// regarding a specific app.
    /// @param appContract The application contract address
    function getNumberOfAcceptedClaims(address appContract)
        external
        view
        returns (uint256);

    /// @notice Get the number of claims staged by the consensus
    /// regarding a specific app.
    /// @param appContract The application contract address
    function getNumberOfStagedClaims(address appContract) external view returns (uint256);

    /// @notice Get the number of claims submitted to the consensus
    /// regarding a specific app.
    /// @param appContract The application contract address
    function getNumberOfSubmittedClaims(address appContract)
        external
        view
        returns (uint256);

    /// @notice Get information about a claim.
    /// @param appContract The application contract address
    /// @param lastProcessedBlockNumber The number of the last processed block
    /// @param machineMerkleRoot The machine Merkle root
    /// @return claim Information about the claim
    function getClaim(
        address appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 machineMerkleRoot
    ) external view returns (Claim memory claim);
}
