// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IConsensus} from "../IConsensus2.sol";

/// @notice A consensus model controlled by a small, immutable set of `n` validators.
/// @notice You can know the value of `n` by calling the `numOfValidators` function.
/// @notice Upon construction, each validator is assigned a unique number between 1 and `n`.
/// These numbers are used internally instead of addresses for gas optimization reasons.
/// @notice You can list the validators in the quorum by calling the `validatorById`
/// function for each ID from 1 to `n`.
interface IQuorum is IConsensus {
    /// @notice Caller is not a validator
    error CallerIsNotValidator();

    /// @notice Get the number of validators.
    function numOfValidators() external view returns (uint256);

    /// @notice Get the ID of a validator.
    /// @param validator The validator address
    /// @dev Validators have IDs greater than zero.
    /// @dev Non-validators are assigned to ID zero.
    function validatorId(address validator) external view returns (uint256);

    /// @notice Get the address of a validator by its ID.
    /// @param id The validator ID
    /// @dev Validator IDs range from 1 to `N`, the total number of validators.
    /// @dev Invalid IDs map to address zero.
    function validatorById(uint256 id) external view returns (address);

    /// @notice Check whether a validator is in favor of some claim.
    /// @param appContract The application contract address
    /// @param epochIndex The epoch index
    /// @param id The ID of the validator
    /// @return Whether validator is in favor of some claim
    /// @dev Assumes the provided ID is valid.
    function isValidatorInFavorOfSomeClaim(
        address appContract,
        uint256 epochIndex,
        uint256 id
    ) external view returns (bool);

    /// @notice Get the number of validators in favor of a given claim.
    /// @param appContract The application contract address
    /// @param epochIndex The epoch index
    /// @param claim The epoch claim
    /// @return Number of validators in favor of claim
    function numOfValidatorsInFavorOf(
        address appContract,
        uint256 epochIndex,
        bytes32 claim
    ) external view returns (uint256);

    /// @notice Check whether a validator is in favor of a given claim.
    /// @param appContract The application contract address
    /// @param epochIndex The epoch index
    /// @param claim The epoch claim
    /// @param id The ID of the validator
    /// @return Whether validator is in favor of claim
    /// @dev Assumes the provided ID is valid.
    function isValidatorInFavorOf(
        address appContract,
        uint256 epochIndex,
        bytes32 claim,
        uint256 id
    ) external view returns (bool);
}
