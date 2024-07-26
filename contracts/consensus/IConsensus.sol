// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

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
interface IConsensus {
    /// @notice MUST trigger when a claim is submitted.
    /// @param submitter The submitter address
    /// @param appContract The application contract address
    /// @param lastProcessedBlockNumber The number of the last processed block
    /// @param claim The root of the Merkle tree of outputs
    event ClaimSubmission(
        address indexed submitter,
        address indexed appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 claim
    );

    /// @notice MUST trigger when a claim is accepted.
    /// @param appContract The application contract address
    /// @param lastProcessedBlockNumber The number of the last processed block
    /// @param claim The root of the Merkle tree of outputs
    event ClaimAcceptance(
        address indexed appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 claim
    );

    /// @notice Submit a claim to the consensus.
    /// @param appContract The application contract address
    /// @param lastProcessedBlockNumber The number of the last processed block
    /// @param claim The root of the Merkle tree of outputs
    /// @dev MUST fire a `ClaimSubmission` event.
    /// @dev MAY fire a `ClaimAcceptance` event, if the acceptance criteria is met.
    function submitClaim(
        address appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 claim
    ) external;

    /// @notice Check if an output Merkle root hash was ever accepted by the consensus
    /// for a particular application.
    /// @param appContract The application contract address
    /// @param claim The root of the Merkle tree of outputs
    function wasClaimAccepted(
        address appContract,
        bytes32 claim
    ) external view returns (bool);
}
