// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IConsensus} from "./IConsensus.sol";

/// @notice Each application has its own stream of inputs.
/// See the `IInputBox` interface for calldata-based on-chain data availability.
/// @notice When an input is fed to the application, it may yield several outputs.
/// @notice Since genesis, a Merkle tree of all outputs ever produced is maintained
/// both inside and outside the Cartesi Machine.
/// @notice The claim that validators may submit to the consensus contract
/// is the root of this Merkle tree after processing all base layer blocks until some height.
/// @notice A validator should be able to save transaction fees by not submitting a claim if it was...
/// - already submitted by the validator (see the `ClaimSubmission` event) or;
/// - already accepted by the consensus (see the `ClaimAcceptance` event).
/// @notice The acceptance criteria for claims may depend on the type of consensus, and is not specified by this interface.
/// For example, a claim may be accepted if it was...
/// - submitted by an authority or;
/// - submitted by the majority of a quorum or;
/// - submitted and not proven wrong after some period of time or;
/// - submitted and proven correct through an on-chain tournament.
interface IClaimSubmitter is IConsensus {
    /// @notice MUST trigger when a claim is submitted.
    /// @param submitter The submitter address
    /// @param appContract The application contract address
    /// @param lastProcessedBlockNumber The number of the last processed block
    /// @param outputsMerkleRoot The outputs Merkle root
    event ClaimSubmission(
        address indexed submitter,
        address indexed appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 outputsMerkleRoot
    );

    /// @notice MUST trigger when a claim is accepted.
    /// @param appContract The application contract address
    /// @param lastProcessedBlockNumber The number of the last processed block
    /// @param outputsMerkleRoot The outputs Merkle root
    event ClaimAcceptance(
        address indexed appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 outputsMerkleRoot
    );

    /// @notice Submit a claim to the consensus.
    /// @param appContract The application contract address
    /// @param lastProcessedBlockNumber The number of the last processed block
    /// @param outputsMerkleRoot The outputs Merkle root
    /// @dev MUST fire a `ClaimSubmission` event.
    /// @dev MAY fire a `ClaimAcceptance` event, if the acceptance criteria is met.
    function submitClaim(
        address appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 outputsMerkleRoot
    ) external;

    /// @notice Get the epoch length, in number of base layer blocks.
    /// @dev The epoch number of a block is defined as
    /// the integer division of the block number by the epoch length.
    function getEpochLength() external view returns (uint256);
}
