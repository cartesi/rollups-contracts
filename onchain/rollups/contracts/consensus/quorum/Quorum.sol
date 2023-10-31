// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {PaymentSplitter} from "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";

import {AbstractConsensus} from "../AbstractConsensus.sol";
import {IConsensus} from "../IConsensus.sol";
import {IHistory} from "../../history/IHistory.sol";

/// @title Quorum consensus
/// @notice A consensus model controlled by a small set of addresses, the validators.
///         In this version, the validator set is immutable.
///         Claims are stored in an auxiliary contract called history.
/// @dev Each validator is assigned an identifier that spans from 1 to N,
///      where N is the total number of validators in the quorum.
///      These identifiers are used internally instead of addresses for optimization reasons.
///      This contract uses OpenZeppelin `PaymentSplitter` and `BitMaps`.
///      For more information on those, please consult OpenZeppelin's official documentation.
contract Quorum is AbstractConsensus, PaymentSplitter {
    using BitMaps for BitMaps.BitMap;

    /// @notice Get the total number of validators.
    uint256 public immutable numOfValidators;

    /// @notice Get the ID of a validator from its address.
    /// @dev Only validators have non-zero IDs.
    mapping(address => uint256) public validatorId;

    /// @notice Get the ID of a validator from its address.
    /// @dev Validator IDs span from 1 to the total number of validators.
    ///      Invalid IDs are assigned to the zero address.
    mapping(uint256 => address) public validatorById;

    /// @notice Voting status of a particular claim.
    /// @param inFavorCount the number of validators in favor of the claim
    /// @param inFavorById the IDs of validators in favor of the claim in bitmap format
    struct VotingStatus {
        uint256 inFavorCount;
        BitMaps.BitMap inFavorById;
    }

    /// @notice The voting status of each claim.
    mapping(bytes => VotingStatus) internal votingStatuses;

    /// @notice The history contract.
    /// @dev See the `getHistory` function.
    IHistory internal immutable history;

    /// @notice Construct a Quorum consensus
    /// @param _validators the list of validators
    /// @param _shares the list of shares
    /// @param _history the history contract
    /// @dev PaymentSplitter checks for duplicates in _validators
    constructor(
        address[] memory _validators,
        uint256[] memory _shares,
        IHistory _history
    ) PaymentSplitter(_validators, _shares) {
        numOfValidators = _validators.length;

        uint256 id = 1;
        for (uint256 i; i < _validators.length; ++i) {
            address validator = _validators[i];
            validatorId[validator] = id;
            validatorById[id] = validator;
            ++id;
        }

        history = _history;
    }

    /// @notice Vote for a claim to be submitted.
    ///         If this is the claim that reaches the majority, then
    ///         the claim is submitted to the history contract.
    ///         The encoding of `_claimData` might vary depending on the
    ///         implementation of the current history contract.
    /// @param _claimData Data for submitting a claim
    /// @dev Can only be called by a validator,
    ///      and the `Quorum` contract must have ownership over
    ///      its current history contract.
    function submitClaim(bytes calldata _claimData) external {
        uint256 id = validatorId[msg.sender];
        require(id != 0, "Quorum: sender is not validator");

        VotingStatus storage votingStatus = votingStatuses[_claimData];
        BitMaps.BitMap storage inFavorById = votingStatus.inFavorById;

        if (!inFavorById.get(id)) {
            // If validator hasn't voted yet, cast their vote
            inFavorById.set(id);

            // If this claim has now just over half of the quorum's votes,
            // then we can submit it to the history contract.
            if (++votingStatus.inFavorCount == 1 + numOfValidators / 2) {
                history.submitClaim(_claimData);
            }
        }
    }

    /// @notice Get an array with the addresses of all validators.
    /// @return Array of addresses of validators
    function validators() external view returns (address[] memory) {
        address[] memory array = new address[](numOfValidators);

        uint256 id = 1;
        for (uint256 i; i < numOfValidators; ++i) {
            array[i] = validatorById[id];
            ++id;
        }

        return array;
    }

    /// @notice Get the number of validator in favor of a claim.
    /// @param _claimData Data for submitting a claim
    /// @return Number of validator in favor of claim.
    function numOfValidatorsInFavorOf(
        bytes calldata _claimData
    ) external view returns (uint256) {
        VotingStatus storage votingStatus = votingStatuses[_claimData];
        return votingStatus.inFavorCount;
    }

    /// @notice Check whether a validator is in favor of a claim.
    /// @param _validatorId The ID of the validator
    /// @param _claimData Data for submitting a claim
    /// @return Array of addresses of validators in favor of claim
    /// @dev Assumes the provided ID is valid
    function isValidatorInFavorOf(
        uint256 _validatorId,
        bytes calldata _claimData
    ) external view returns (bool) {
        VotingStatus storage votingStatus = votingStatuses[_claimData];
        BitMaps.BitMap storage inFavorById = votingStatus.inFavorById;
        return inFavorById.get(_validatorId);
    }

    /// @notice Get an array with the addresses of all validators in favor of a claim.
    /// @param _claimData Data for submitting a claim
    /// @return Array of addresses of validators in favor of claim
    function validatorsInFavorOf(
        bytes calldata _claimData
    ) external view returns (address[] memory) {
        VotingStatus storage votingStatus = votingStatuses[_claimData];
        BitMaps.BitMap storage inFavorById = votingStatus.inFavorById;

        uint256 validatorsLeft = votingStatus.inFavorCount;
        address[] memory array = new address[](validatorsLeft);

        uint256 id = 1;
        while (validatorsLeft > 0) {
            if (inFavorById.get(id)) {
                array[--validatorsLeft] = validatorById[id];
            }
            ++id;
        }

        return array;
    }

    /// @notice Get the history contract.
    /// @return The history contract
    function getHistory() external view returns (IHistory) {
        return history;
    }

    /// @notice Get a claim from the current history.
    ///         The encoding of `_proofContext` might vary depending on the
    ///         implementation of the current history contract.
    /// @inheritdoc IConsensus
    function getClaim(
        address _dapp,
        bytes calldata _proofContext
    ) external view override returns (bytes32, uint256, uint256) {
        return history.getClaim(_dapp, _proofContext);
    }
}
