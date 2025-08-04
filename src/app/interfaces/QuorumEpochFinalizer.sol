// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {EpochManager} from "./EpochManager.sol";

/// @notice Reaches epoch finality through a quorum-based majority voting system.
/// @dev The quorum has a fixed number of validators, `N`.
/// The number of validators of a quorum can range from 1 up to 255.
/// Each validator in a quorum is assigned a single, unique ID from `1` to `N`.
/// The zero ID is reserved as sentinel value for "invalid validator ID".
/// Votes are represented as bitmaps to save gas spent on storage operations.
/// The i-th most significant bit is set iff the validator of ID `i` has voted.
/// The number of bits set in the bitmap represent the number of votes.
/// Since `N < 256`, this bitmap can be stored in a single 256-bit EVM word.
/// Vote bitmaps are typed as `bytes32` values in Solidity.
/// The following example bitmap represents votes from validators 7, 21, and 42:
/// `0x0000000000000000000000000000000000000000000000000000040000200080`.
/// Liveness depends on a majority of validators voting on the same post-epoch state.
/// Security depends on a majority of validators voting on the correct post-epoch state.
interface QuorumEpochFinalizer is EpochManager {
    /// @notice This event is emitted when a validator votes on a post-epoch state.
    /// @param epochIndex The epoch index
    /// @param postEpochStateRoot The post-epoch state root
    /// @param validatorAddress The validator address
    event Vote(
        uint256 indexed epochIndex,
        bytes32 indexed postEpochStateRoot,
        address indexed validatorAddress
    );

    /// @notice This error is raised when someone
    /// tries to vote on a post-epoch state but
    /// they are not a validator.
    /// @param sender The message sender
    error MessageSenderIsNotValidator(address sender);

    /// @notice This error is raised when a validator
    /// tries to vote on a post-epoch state having
    /// already cast a vote for the same epoch.
    error VoteAlreadyCastForEpoch();

    /// @notice Get the number of validators in the quorum.
    /// @return numOfValidators The number of validators
    /// @dev Validator IDs range between 1 and the number of validators.
    function getNumberOfValidators() external view returns (uint8 numOfValidators);

    /// @notice Get the address of a validator by its ID.
    /// @param validatorId The validator ID
    /// @return validatorAddress The validator address
    /// @dev Invalid validator IDs map to the zero address.
    function getValidatorAddressById(uint8 validatorId)
        external
        view
        returns (address validatorAddress);

    /// @notice Get the ID of a validator by its address.
    /// @param validatorAddress The validator address
    /// @return validatorId The validator ID
    /// @dev Addresses of non-validators map to the zero ID.
    function getValidatorIdByAddress(address validatorAddress)
        external
        view
        returns (uint8 validatorId);

    /// @notice Get a bitmap that represents all validators that have
    /// voted on a particular post-epoch state in the context of an epoch.
    /// @param epochIndex The epoch index
    /// @param postEpochStateRoot The post-epoch state root
    /// @return voteBitmap The vote bitmap
    function getVoteBitmap(uint256 epochIndex, bytes32 postEpochStateRoot)
        external
        view
        returns (bytes32 voteBitmap);

    /// @notice Get a bitmap that represents all validators that have
    /// voted on any post-epoch state in the context of an epoch.
    /// @param epochIndex The epoch index
    /// @return aggregatedVoteBitmap The aggregated vote bitmap
    function getAggregatedVoteBitmap(uint256 epochIndex)
        external
        view
        returns (bytes32 aggregatedVoteBitmap);

    /// @notice Vote on a post-epoch state.
    /// @param currentEpochIndex The current epoch index
    /// @param postEpochStateRoot The post-epoch state root
    /// @dev If message sender is not a validator, raises `MessageSenderIsNotValidator`.
    /// If the epoch index is not the current epoch index, raises `InvalidCurrentEpochIndex`.
    /// If the validator has already cast a vote, raises `VoteAlreadyCastForEpoch`.
    function vote(uint256 currentEpochIndex, bytes32 postEpochStateRoot) external;
}
