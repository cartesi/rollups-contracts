// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IConsensus} from "../IConsensus.sol";

/// @notice A consensus model controlled by a small, immutable set of `n` validators.
/// @notice You can know the value of `n` by calling the `numOfValidators` function.
/// @notice Upon construction, each validator is assigned a unique number between 1 and `n`.
/// @notice These numbers are used internally instead of addresses for gas optimization reasons.
/// @notice You can list the validators in the quorum by calling the `validatorById`
/// function for each ID from 1 to `n`.
interface IQuorum is IConsensus {
    /// @notice Get the number of validators.
    function numOfValidators() external view returns (uint256);

    /// @notice Get the ID of a validator.
    /// @param validator The validator address
    /// @dev Validators have IDs greater than zero.
    /// @dev Non-validators are assigned ID zero.
    function validatorId(address validator) external view returns (uint256);

    /// @notice Get the address of a validator by its ID.
    /// @param id The validator ID
    /// @dev Validator IDs range from 1 to `N`, the total number of validators.
    /// @dev Invalid IDs map to address zero.
    function validatorById(uint256 id) external view returns (address);

    /// @notice Get the number of validators in favor of any claim in a given epoch.
    /// @param appContract The application contract address
    /// @param lastProcessedBlockNumber The number of the last processed block
    /// @return The number of validators in favor of any claim in the epoch
    function numOfValidatorsInFavorOfAnyClaimInEpoch(
        address appContract,
        uint256 lastProcessedBlockNumber
    ) external view returns (uint256);

    /// @notice Check whether a validator is in favor of any claim in a given epoch.
    /// @param appContract The application contract address
    /// @param lastProcessedBlockNumber The number of the last processed block
    /// @param id The ID of the validator
    /// @return Whether the validator is in favor of any claim in the epoch
    /// @dev Assumes the provided ID is valid.
    function isValidatorInFavorOfAnyClaimInEpoch(
        address appContract,
        uint256 lastProcessedBlockNumber,
        uint256 id
    ) external view returns (bool);

    /// @notice Get the number of validators in favor of a claim.
    /// @param appContract The application contract address
    /// @param lastProcessedBlockNumber The number of the last processed block
    /// @param outputsMerkleRoot The outputs Merkle root
    /// @return The number of validators in favor of the claim
    function numOfValidatorsInFavorOf(
        address appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 outputsMerkleRoot
    ) external view returns (uint256);

    /// @notice Check whether a validator is in favor of a claim.
    /// @param appContract The application contract address
    /// @param lastProcessedBlockNumber The number of the last processed block
    /// @param outputsMerkleRoot The outputs Merkle root
    /// @param id The ID of the validator
    /// @return Whether the validator is in favor of the claim
    /// @dev Assumes the provided ID is valid.
    function isValidatorInFavorOf(
        address appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 outputsMerkleRoot,
        uint256 id
    ) external view returns (bool);
}
