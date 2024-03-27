// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {InputRange} from "../common/InputRange.sol";

/// @notice Provides data availability of epoch hashes for applications.
/// @notice An epoch hash is produced after the machine processes a range of inputs and the epoch is finalized.
/// This hash can be later used to prove that any given output was produced by the machine during the epoch.
/// @notice After an epoch is finalized, a validator may submit a claim containing the application contract address,
/// the range of inputs accepted during the epoch, and the epoch hash.
/// @notice Validators may synchronize epoch finalization, but such mechanism is not specified by this interface.
/// @notice A validator should be able to save transaction fees by not submitting a claim if it was...
/// - already submitted by the validator (see the `ClaimSubmission` event) or;
/// - already accepted by the consensus (see the `ClaimAcceptance` event).
/// @notice The acceptance criteria for claims may depend on the type of consensus, and is not specified by this interface.
/// For example, a claim may be accepted if it was...
/// - submitted by an authority or;
/// - submitted by the majority of a quorum or;
/// - submitted and not proven wrong after some period of time.
interface IConsensus {
    /// @notice MUST trigger when a claim is submitted.
    /// @param submitter The submitter address
    /// @param appContract The application contract address
    /// @param inputRange The input range
    /// @param epochHash The epoch hash
    /// @dev Overwrites any previous submissions regarding `submitter`, `appContract` and `inputRange`.
    event ClaimSubmission(
        address indexed submitter,
        address indexed appContract,
        InputRange inputRange,
        bytes32 epochHash
    );

    /// @notice MUST trigger when a claim is accepted.
    /// @param appContract The application contract address
    /// @param inputRange The input range
    /// @param epochHash The epoch hash
    /// @dev MUST be triggered after some `ClaimSubmission` event regarding `appContract`, `inputRange` and `epochHash`.
    /// @dev Overwrites any previous acceptances regarding `appContract` and `inputRange`.
    event ClaimAcceptance(
        address indexed appContract,
        InputRange inputRange,
        bytes32 epochHash
    );

    /// @notice Submit a claim to the consensus.
    /// @param appContract The application contract address
    /// @param inputRange The input range
    /// @param epochHash The epoch hash
    /// @dev MUST fire a `ClaimSubmission` event.
    /// @dev MAY fire a `ClaimAcceptance` event, if the acceptance criteria is met.
    function submitClaim(
        address appContract,
        InputRange calldata inputRange,
        bytes32 epochHash
    ) external;

    /// @notice Get the epoch hash for a certain application and input range.
    /// @param appContract The application contract address
    /// @param inputRange The input range
    /// @return epochHash The epoch hash
    /// @dev For claimed epochs, must return the epoch hash of the last accepted claim.
    /// @dev For unclaimed epochs, MUST either revert or return `bytes32(0)`.
    function getEpochHash(
        address appContract,
        InputRange calldata inputRange
    ) external view returns (bytes32 epochHash);
}
