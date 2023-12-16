// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {InputRange} from "../common/InputRange.sol";

/// @notice Provides epoch hashes for DApps.
/// @notice An epoch hash is produced after the machine processes a range of inputs and the epoch is finalized.
/// This hash can be later used to prove that any given output was produced by the machine during the epoch.
/// @notice After an epoch is finalized, a validator may submit a claim containing: the address of the DApp contract,
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
    /// @notice A claim was submitted to the consensus.
    /// @param submitter The submitter address
    /// @param dapp The DApp contract address
    /// @param inputRange The input range
    /// @param epochHash The epoch hash
    /// @dev Overwrites any previous submissions regarding `submitter`, `dapp` and `inputRange`.
    event ClaimSubmission(
        address indexed submitter,
        address indexed dapp,
        InputRange inputRange,
        bytes32 epochHash
    );

    /// @notice A claim was accepted by the consensus.
    /// @param dapp The DApp contract address
    /// @param inputRange The input range
    /// @param epochHash The epoch hash
    /// @dev MUST be triggered after some `ClaimSubmission` event regarding `dapp`, `inputRange` and `epochHash`.
    /// @dev Overwrites any previous acceptances regarding `dapp` and `inputRange`.
    event ClaimAcceptance(
        address indexed dapp,
        InputRange inputRange,
        bytes32 epochHash
    );

    /// @notice Submit a claim to the consensus.
    /// @param dapp The DApp contract address
    /// @param inputRange The input range
    /// @param epochHash The epoch hash
    /// @dev On success, MUST trigger a `ClaimSubmission` event.
    function submitClaim(
        address dapp,
        InputRange calldata inputRange,
        bytes32 epochHash
    ) external;

    /// @notice Get the epoch hash for a certain DApp and input range.
    /// @param dapp The DApp contract address
    /// @param inputRange The input range
    /// @return epochHash The epoch hash
    /// @dev For claimed epochs, must return the epoch hash of the last accepted claim.
    /// @dev For unclaimed epochs, MUST either revert or return `bytes32(0)`.
    function getEpochHash(
        address dapp,
        InputRange calldata inputRange
    ) external view returns (bytes32 epochHash);
}
