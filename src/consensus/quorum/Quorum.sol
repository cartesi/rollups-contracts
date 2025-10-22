// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IERC165} from "@openzeppelin-contracts-5.2.0/utils/introspection/IERC165.sol";
import {BitMaps} from "@openzeppelin-contracts-5.2.0/utils/structs/BitMaps.sol";

import {AbstractConsensus} from "../AbstractConsensus.sol";
import {IQuorum} from "./IQuorum.sol";

contract Quorum is IQuorum, AbstractConsensus {
    using BitMaps for BitMaps.BitMap;

    /// @notice The total number of validators.
    /// @notice See the `numOfValidators` function.
    uint256 private immutable _NUM_OF_VALIDATORS;

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

    /// @notice Votes indexed by application contract address,
    /// and last processed block number.
    /// @dev See the `numOfValidatorsInFavorOfAnyClaimInEpoch`
    /// and `isValidatorInFavorOfAnyClaimInEpoch` functions.
    mapping(address => mapping(uint256 => Votes)) private _allVotes;

    /// @notice Votes indexed by application contract address,
    /// last processed block number and outputs Merkle root.
    /// @dev See the `numOfValidatorsInFavorOf` and `isValidatorInFavorOf` functions.
    mapping(address => mapping(uint256 => mapping(bytes32 => Votes))) private _votes;

    /// @param validators The array of validator addresses
    /// @param epochLength The epoch length
    /// @dev Duplicates in the `validators` array are ignored.
    /// @dev Reverts if the epoch length is zero.
    constructor(address[] memory validators, uint256 epochLength)
        AbstractConsensus(epochLength)
    {
        uint256 n;
        for (uint256 i; i < validators.length; ++i) {
            address validator = validators[i];
            if (_validatorId[validator] == 0) {
                uint256 id = ++n;
                _validatorId[validator] = id;
                _validatorById[id] = validator;
            }
        }
        _NUM_OF_VALIDATORS = n;
    }

    function submitClaim(
        address appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 outputsMerkleRoot
    ) external override {
        uint256 id = _validatorId[msg.sender];
        require(id > 0, "Quorum: caller is not validator");

        _validateLastProcessedBlockNumber(lastProcessedBlockNumber);

        emit ClaimSubmitted(
            msg.sender, appContract, lastProcessedBlockNumber, outputsMerkleRoot
        );

        Votes storage votes =
            _getVotes(appContract, lastProcessedBlockNumber, outputsMerkleRoot);

        Votes storage allVotes = _getAllVotes(appContract, lastProcessedBlockNumber);

        // Skip storage changes if validator already voted
        // for the same exact claim before
        if (!votes.inFavorById.get(id)) {
            // Revert if validator has submitted another claim for the same epoch
            require(
                !allVotes.inFavorById.get(id),
                NotFirstClaim(appContract, lastProcessedBlockNumber)
            );

            // Register vote (for any claim in the epoch)
            allVotes.inFavorById.set(id);
            ++allVotes.inFavorCount;

            // Register vote (for the specific claim)
            // and accept the claim if a majority has been reached
            votes.inFavorById.set(id);
            if (++votes.inFavorCount == 1 + _NUM_OF_VALIDATORS / 2) {
                _acceptClaim(appContract, lastProcessedBlockNumber, outputsMerkleRoot);
            }
        }
    }

    function numOfValidators() external view override returns (uint256) {
        return _NUM_OF_VALIDATORS;
    }

    function validatorId(address validator) external view override returns (uint256) {
        return _validatorId[validator];
    }

    function validatorById(uint256 id) external view override returns (address) {
        return _validatorById[id];
    }

    function numOfValidatorsInFavorOfAnyClaimInEpoch(
        address appContract,
        uint256 lastProcessedBlockNumber
    ) external view override returns (uint256) {
        return _getAllVotes(appContract, lastProcessedBlockNumber).inFavorCount;
    }

    function isValidatorInFavorOfAnyClaimInEpoch(
        address appContract,
        uint256 lastProcessedBlockNumber,
        uint256 id
    ) external view override returns (bool) {
        return _getAllVotes(appContract, lastProcessedBlockNumber).inFavorById.get(id);
    }

    function numOfValidatorsInFavorOf(
        address appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 outputsMerkleRoot
    ) external view override returns (uint256) {
        return _getVotes(appContract, lastProcessedBlockNumber, outputsMerkleRoot)
        .inFavorCount;
    }

    function isValidatorInFavorOf(
        address appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 outputsMerkleRoot,
        uint256 id
    ) external view override returns (bool) {
        return _getVotes(appContract, lastProcessedBlockNumber, outputsMerkleRoot)
            .inFavorById.get(id);
    }

    /// @notice Get a `Votes` structure from storage from a given epoch.
    /// @param appContract The application contract address
    /// @param lastProcessedBlockNumber The number of the last processed block
    /// @return The `Votes` structure related to all claims in a given epoch
    function _getAllVotes(address appContract, uint256 lastProcessedBlockNumber)
        internal
        view
        returns (Votes storage)
    {
        return _allVotes[appContract][lastProcessedBlockNumber];
    }

    /// @notice Get a `Votes` structure from storage from a given claim.
    /// @param appContract The application contract address
    /// @param lastProcessedBlockNumber The number of the last processed block
    /// @param outputsMerkleRoot The outputs Merkle root
    /// @return The `Votes` structure related to a given claim
    function _getVotes(
        address appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 outputsMerkleRoot
    ) internal view returns (Votes storage) {
        return _votes[appContract][lastProcessedBlockNumber][outputsMerkleRoot];
    }

    /// @inheritdoc AbstractConsensus
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(IERC165, AbstractConsensus)
        returns (bool)
    {
        return interfaceId == type(IQuorum).interfaceId
            || super.supportsInterface(interfaceId);
    }
}
