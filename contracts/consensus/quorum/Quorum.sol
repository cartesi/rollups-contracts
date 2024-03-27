// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";

import {AbstractConsensus} from "../AbstractConsensus.sol";
import {InputRange} from "../../common/InputRange.sol";

/// @notice A consensus model controlled by a small, immutable set of `n` validators.
/// @notice You can know the value of `n` by calling the `numOfValidators` function.
/// @notice Upon construction, each validator is assigned a unique number between 1 and `n`.
/// These numbers are used internally instead of addresses for optimization reasons.
/// @notice You can list the validators in the quorum by calling the `validatorById`
/// function for each ID from 1 to `n`.
contract Quorum is AbstractConsensus {
    using BitMaps for BitMaps.BitMap;

    /// @notice The total number of validators.
    /// @notice See the `numOfValidators` function.
    uint256 private immutable _numOfValidators;

    /// @notice Validator IDs indexed by address.
    /// @notice See the `validatorId` function.
    /// @dev Non-validators are assigned to ID zero.
    /// @dev Validators have IDs greater than zero.
    mapping(address => uint256) private _validatorId;

    /// @notice Validator addresses indexed by ID.
    /// @notice See the `validatorById` function.
    /// @dev Invalid IDs map to address zero.
    mapping(uint256 => address) private _validatorById;

    /// @notice Votes in favor of a particular claim.
    /// @param inFavorCount The number of validators in favor of the claim
    /// @param inFavorById The set of validators in favor of the claim
    /// @dev `inFavorById` is a bitmap indexed by validator IDs.
    struct Votes {
        uint256 inFavorCount;
        BitMaps.BitMap inFavorById;
    }

    /// @notice Votes indexed by claim
    /// (application contract address, first input index, last input index, and epoch hash).
    /// @dev See the `numOfValidatorsInFavorOf` and `isValidatorInFavorOf` functions.
    mapping(address => mapping(uint256 => mapping(uint256 => mapping(bytes32 => Votes))))
        private _votes;

    /// @param validators The array of validator addresses
    /// @dev Duplicates in the `validators` array are ignored.
    constructor(address[] memory validators) {
        uint256 n;
        for (uint256 i; i < validators.length; ++i) {
            address validator = validators[i];
            if (_validatorId[validator] == 0) {
                uint256 id = ++n;
                _validatorId[validator] = id;
                _validatorById[id] = validator;
            }
        }
        _numOfValidators = n;
    }

    /// @notice Submit a claim.
    /// @notice If the majority of the quorum submit a claim, it is accepted.
    /// @param appContract The application contract address
    /// @param r The input range
    /// @param epochHash The epoch hash
    /// @dev Can only be called by a validator.
    function submitClaim(
        address appContract,
        InputRange calldata r,
        bytes32 epochHash
    ) external {
        uint256 id = _validatorId[msg.sender];
        require(id > 0, "Quorum: caller is not validator");

        emit ClaimSubmission(msg.sender, appContract, r, epochHash);

        Votes storage votes = _getVotes(appContract, r, epochHash);

        if (!votes.inFavorById.get(id)) {
            votes.inFavorById.set(id);
            if (++votes.inFavorCount == 1 + _numOfValidators / 2) {
                _acceptClaim(appContract, r, epochHash);
            }
        }
    }

    /// @notice Get the number of validators.
    function numOfValidators() external view returns (uint256) {
        return _numOfValidators;
    }

    /// @notice Get the ID of a validator.
    /// @param validator The validator address
    /// @dev Validators have IDs greater than zero.
    /// @dev Non-validators are assigned to ID zero.
    function validatorId(address validator) external view returns (uint256) {
        return _validatorId[validator];
    }

    /// @notice Get the address of a validator by its ID.
    /// @param id The validator ID
    /// @dev Validator IDs range from 1 to `N`, the total number of validators.
    /// @dev Invalid IDs map to address zero.
    function validatorById(uint256 id) external view returns (address) {
        return _validatorById[id];
    }

    /// @notice Get the number of validators in favor of a claim.
    /// @param appContract The application contract address
    /// @param r The input range
    /// @param epochHash The epoch hash
    /// @return Number of validators in favor of claim
    function numOfValidatorsInFavorOf(
        address appContract,
        InputRange calldata r,
        bytes32 epochHash
    ) external view returns (uint256) {
        return _getVotes(appContract, r, epochHash).inFavorCount;
    }

    /// @notice Check whether a validator is in favor of a claim.
    /// @param appContract The application contract address
    /// @param r The input range
    /// @param epochHash The epoch hash
    /// @param id The ID of the validator
    /// @return Whether validator is in favor of claim
    /// @dev Assumes the provided ID is valid.
    function isValidatorInFavorOf(
        address appContract,
        InputRange calldata r,
        bytes32 epochHash,
        uint256 id
    ) external view returns (bool) {
        return _getVotes(appContract, r, epochHash).inFavorById.get(id);
    }

    /// @notice Get a `Votes` structure from storage from a given claim.
    /// @param appContract The application contract address
    /// @param r The input range
    /// @param epochHash The epoch hash
    /// @return The `Votes` structure related to given claim
    function _getVotes(
        address appContract,
        InputRange calldata r,
        bytes32 epochHash
    ) internal view returns (Votes storage) {
        return _votes[appContract][r.firstIndex][r.lastIndex][epochHash];
    }
}
