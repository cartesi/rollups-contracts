// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @title Consensus interface
///
/// Authority (multi dapp):
/// * initial state
/// []
/// * anyone (!!!) calls sealEpoch
/// [waiting_claims]
/// * the authority owner (!!!) calls submitClaim
/// [settled]
///
/// Quorum (multi dapp):
/// * initial state
/// []
/// * anyone (!!!) calls sealEpoch
/// [waiting_claims]
/// * validators submit claims but they doen't form
/// an absolute majority of the quorum
/// [waiting_claims]
/// * the majority of validators submit the same claim
/// [settled]
///
/// Dave PRT (single dapp):
/// * initial state
/// [waiting_dispute (PRT)]
/// * dispute is resolved
/// [settled]
/// * someone calls sealEpoch
/// [settled, waiting_dispute (PRT)]
///
interface IConsensus {
    /// @notice Epoch phases
    enum Phase {
        /// @notice Waiting for claims to be submitted.
        WAITING_FOR_CLAIMS,
        /// @notice Waiting for dispute to be resolved.
        WAITING_FOR_DISPUTE_RESOLUTION,
        /// @notice The result has been settled.
        SETTLED
    }

    /// @notice Range of base layer blocks of the form [lower, upper)
    struct BlockRange {
        uint256 lowerBound;
        uint256 upperBound;
    }

    /// @notice An epoch was sealed.
    /// @dev This also means that an epoch was created
    /// and is now accumulating inputs.
    event SealedEpoch(
        address indexed appContract,
        uint256 indexed epochIndex,
        BlockRange blockRange
    );

    /// @notice A claim was submitted.
    event ClaimSubmission(
        address indexed appContract,
        uint256 indexed epochIndex,
        address indexed submitter,
        bytes32 claim
    );

    /// @notice The epoch claim is under dispute.
    /// @dev The interface of the dispute resolution module
    /// can be inferred via ERC-165.
    event DisputedEpoch(
        address indexed appContract,
        uint256 indexed epochIndex,
        IERC165 disputeResolutionModule
    );

    /// @notice The epoch claim is settled.
    event SettledEpoch(
        address indexed appContract,
        uint256 indexed epochIndex,
        bytes32 claim
    );

    /// @notice Cannot seal an epoch yet.
    error CannotSealEpoch(address appContract);

    /// @notice An invalid epoch index was provided.
    error InvalidEpochIndex(address appContract, uint256 epochIndex);

    /// @notice The epoch is an invalid phase.
    error InvalidEpochPhase(address appContract, uint256 epochIndex);

    /// @notice Get the number of sealed epochs of an application.
    function getNumberOfSealedEpochs(
        address appContract
    ) external view returns (uint256);

    /// @notice Given an application, check if can seal a new epoch.
    function canSealEpoch(address appContract) external view returns (bool);

    /// @notice Given an application, seal a new epoch.
    function sealEpoch(address appContract) external;

    /// @notice Given an application, get the phase of an epoch.
    /// @dev If the epoch index is invalid, an InvalidEpochIndex error is raised.
    function getEpochPhase(
        address appContract,
        uint256 epochIndex
    ) external view returns (Phase);

    /// @notice Given an application, get the block range of a sealed epoch.
    /// @dev If the epoch index is invalid, an InvalidEpochIndex error is raised.
    function getSealedEpochBlockRange(
        address appContract,
        uint256 epochIndex
    ) external view returns (BlockRange memory);

    /// @notice Given an application, submit an epoch claim.
    /// @dev Should only be called for epochs in the WAITING_FOR_CLAIMS phase.
    /// @dev If the epoch index is invalid, an InvalidEpochIndex error is raised.
    /// @dev If the epoch phase is invalid, an InvalidEpochPhase error is raised.
    function submitClaim(
        address appContract,
        uint256 epochIndex,
        bytes32 claim
    ) external;

    /// @notice Given an application, get the dispute resolution module of an epoch.
    /// @dev Should only be called for epochs in the WAITING_FOR_DISPUTE_RESOLUTION phase.
    /// @dev One should be able to infer the interface of the dispute resolution module with ERC-165.
    /// @dev If the epoch index is invalid, an InvalidEpochIndex error is raised.
    /// @dev If the epoch phase is invalid, an InvalidEpochPhase error is raised.
    function getDisputeResolutionModule(
        address appContract,
        uint256 epochIndex
    ) external view returns (IERC165);

    /// @notice Given an application, get the claim of a settled epoch.
    /// @dev Should only be called for epochs in the SETTLED phase.
    /// @dev If the epoch index is invalid, an InvalidEpochIndex error is raised.
    /// @dev If the epoch phase is invalid, an InvalidEpochPhase error is raised.
    function getSettledEpochClaim(
        address appContract,
        uint256 epochIndex
    ) external view returns (bytes32);
}
