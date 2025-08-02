// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

/// @notice Reaches epoch finality through a quorum-based majority voting system.
/// @dev The quorum has a fixed number of validators, `N`.
/// The number of validators of a quorum can range from 1 up to 255.
/// Each validator in a quorum is assigned a single, unique ID from `1` to `N`.
/// The zero ID is reserved as sentinel value for "invalid validator ID".
/// Votes are represented as bitmaps to save gas spent on storage operations.
/// The i-th most significant bit is set iff the validator of ID `i` has voted.
/// Since `N < 256`, this bitmap can be stored in a single 256-bit EVM word.
/// Vote bitmaps are typed as `bytes32` values in Solidity.
/// The following example bitmap represents votes from validators 7, 21, and 42:
/// `0x0000000000000000000000000000000000000000000000000000040000200080`.
/// Liveness depends on a majority of validators voting on the same post-epoch state.
/// Security depends on a majority of validators voting on the correct post-epoch state.
interface QuorumEpochFinalizer {
    /// @notice This event is emitted when a validator votes on a post-epoch state.
    /// @param epochIndex The epoch index
    /// @param postEpochStateRoot The post-epoch state root
    /// @param validatorAddress The validator address
    event Vote(
        uint256 indexed epochIndex,
        bytes32 indexed postEpochStateRoot,
        address indexed validatorAddress
    );

    /// @notice This error is raised when a validator
    /// tries to vote on a post-epoch state having
    /// already cast a vote for the same epoch.
    /// @param epochIndex The epoch index
    error VoteAlreadyCastForEpoch(uint256 epochIndex);

    /// @notice Get the number of validators in the quorum.
    /// @return numOfValidators The number of validators
    /// @dev Validator IDs range from 1 to the number of validators.
    function getNumberOfValidators() external view returns (uint8 numOfValidators);

    /// @notice Get the address of a validator by its ID.
    /// @param validatorId The validator ID
    /// @return validatorAddress The validator address
    /// @dev Invalid IDs map to the zero address.
    function getValidatorAddressById(uint8 validatorId)
        external
        view
        returns (address validatorAddress);

    /// @notice Get the ID of a validator by its address.
    /// @param validatorAddress The validator address
    /// @return validatorId The validator ID
    /// @dev Invalid addresses map to the zero ID.
    function getValidatorIdByAddress(address validatorAddress)
        external
        view
        returns (uint8 validatorId);

    /// @notice Get a bitmap that captures all votes on a given post-epoch state.
    /// @param epochIndex The epoch index
    /// @param postEpochStateRoot The post-epoch state root
    /// @return voteBitmap The vote bitmap
    function getVoteBitmap(uint256 epochIndex, bytes32 postEpochStateRoot)
        external
        view
        returns (bytes32 voteBitmap);

    /// @notice Get a bitmap that aggregates all votes on any post-epoch state.
    /// @param epochIndex The epoch index
    /// @return aggregatedVoteBitmap The aggregated vote bitmap
    function getAggregatedVoteBitmap(uint256 epochIndex)
        external
        view
        returns (bytes32 aggregatedVoteBitmap);

    /// @notice Vote on a post-epoch state.
    /// @param epochIndex The epoch index
    /// @param postEpochStateRoot The post-epoch state root
    function vote(uint256 epochIndex, bytes32 postEpochStateRoot) external;
}
