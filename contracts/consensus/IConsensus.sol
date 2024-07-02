// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

/// @notice Provides consensus over the set of valid output Merkle root hashes for applications.
/// @notice The latest output Merkle root hash is available after the machine processes every input.
/// This hash can be later used to prove that any given output was ever produced by the machine.
/// @notice After an epoch is finalized, a validator may submit a claim containing the application contract address,
/// and the output Merkle root hash.
/// @notice Validators may synchronize epoch finalization, but such mechanism is not specified by this interface.
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
    /// @param claim The output Merkle root hash
    event ClaimSubmission(
        address indexed submitter,
        address indexed appContract,
        bytes32 claim
    );

    /// @notice MUST trigger when a claim is accepted.
    /// @param appContract The application contract address
    /// @param claim The output Merkle root hash
    /// @dev MUST be triggered after some `ClaimSubmission` event regarding `appContract`.
    event ClaimAcceptance(address indexed appContract, bytes32 claim);

    /// @notice Submit a claim to the consensus.
    /// @param appContract The application contract address
    /// @param claim The output Merkle root hash
    /// @dev MUST fire a `ClaimSubmission` event.
    /// @dev MAY fire a `ClaimAcceptance` event, if the acceptance criteria is met.
    function submitClaim(address appContract, bytes32 claim) external;

    /// @notice Check if an output Merkle root hash was ever accepted by the consensus
    /// for a particular application.
    /// @param appContract The application contract address
    /// @param claim The output Merkle root hash
    function wasClaimAccepted(
        address appContract,
        bytes32 claim
    ) external view returns (bool);
}
