// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IOutputsMerkleRootValidator} from "./IOutputsMerkleRootValidator.sol";

/// @notice Each application has its own stream of inputs.
/// See the `IInputBox` interface for calldata-based on-chain data availability.
/// @notice When an input is fed to the application, it may yield several outputs.
/// @notice Since genesis, a Merkle tree of all outputs ever produced is maintained
/// both inside and outside the Cartesi Machine.
/// @notice The claim that validators may submit to the consensus contract
/// is the root of this Merkle tree after processing all base layer blocks until some height.
/// @notice A validator should be able to save transaction fees by not submitting a claim if it was...
/// - already submitted by the validator (see the `ClaimSubmitted` event) or;
/// - already accepted by the consensus (see the `ClaimAccepted` event).
/// @notice The acceptance criteria for claims may depend on the type of consensus, and is not specified by this interface.
/// For example, a claim may be accepted if it was...
/// - submitted by an authority or;
/// - submitted by the majority of a quorum or;
/// - submitted and not proven wrong after some period of time or;
/// - submitted and proven correct through an on-chain tournament.
interface IConsensus is IOutputsMerkleRootValidator {
    /// @notice MUST trigger when a claim is submitted.
    /// @param submitter The submitter address
    /// @param appContract The application contract address
    /// @param lastProcessedBlockNumber The number of the last processed block
    /// @param outputsMerkleRoot The outputs Merkle root
    event ClaimSubmitted(
        address indexed submitter,
        address indexed appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 outputsMerkleRoot
    );

    /// @notice MUST trigger when a claim is accepted.
    /// @param appContract The application contract address
    /// @param lastProcessedBlockNumber The number of the last processed block
    /// @param outputsMerkleRoot The outputs Merkle root
    /// @dev For each application and lastProcessedBlockNumber,
    /// there can be at most one accepted claim.
    event ClaimAccepted(
        address indexed appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 outputsMerkleRoot
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

    /// @notice Submit a claim to the consensus.
    /// @param appContract The application contract address
    /// @param lastProcessedBlockNumber The number of the last processed block
    /// @param outputsMerkleRoot The outputs Merkle root
    /// @dev MUST fire a `ClaimSubmitted` event.
    /// @dev MAY fire a `ClaimAccepted` event, if the acceptance criteria is met.
    function submitClaim(
        address appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 outputsMerkleRoot
    ) external;

    /// @notice Get the epoch length, in number of base layer blocks.
    /// @dev The epoch number of a block is defined as
    /// the integer division of the block number by the epoch length.
    function getEpochLength() external view returns (uint256);

    /// @notice Get the number of claims accepted by the consensus.
    function getNumberOfAcceptedClaims() external view returns (uint256);
}
