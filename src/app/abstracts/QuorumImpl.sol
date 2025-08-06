// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {EpochManagerImpl} from "./EpochManagerImpl.sol";
import {Lib256Bitmap} from "../../library/Lib256Bitmap.sol";
import {Quorum} from "../interfaces/Quorum.sol";

abstract contract QuorumImpl is EpochManagerImpl, Quorum {
    using Lib256Bitmap for bytes32;

    /// @notice No validator was provided.
    error NoValidator();

    /// @notice Too many validators were provided.
    error TooManyValidators();

    /// @notice A duplicated validator was provided.
    /// @param validator The duplicated validator
    error DuplicatedValidator(address validator);

    uint8 immutable _NUM_OF_VALIDATORS;

    mapping(address => uint8) private _validatorIdByAddress;
    mapping(uint256 => bytes32) private _aggregatedVoteBitmaps;
    mapping(uint256 => mapping(bytes32 => bytes32)) private _voteBitmaps;

    /// @notice Initialize the quorum.
    /// @param validators The array of validator addresses
    /// @dev If the validators array is empty, raises `NoValidator`.
    /// If the validator array has over 255 elements, raises `TooManyValidators`.
    /// If the validator array has duplicate elements, raises `DuplicatedValidator`.
    constructor(address[] memory validators) {
        uint256 numOfValidators = validators.length;
        require(numOfValidators >= 1, NoValidator());
        require(numOfValidators <= 255, TooManyValidators());
        for (uint256 i; i < numOfValidators; ++i) {
            address validator = validators[i];
            require(_validatorIdByAddress[validator] == 0, DuplicatedValidator(validator));
            uint8 id = uint8(i + 1);
            _validatorIdByAddress[validator] = id;
        }
        _NUM_OF_VALIDATORS = uint8(numOfValidators);
        emit Init(validators);
    }

    function getEpochFinalizerInterfaceId() external pure override returns (bytes4) {
        return type(Quorum).interfaceId;
    }

    function closeCurrentEpoch(uint256 currentEpochIndex) external override {
        ensureCurrentEpochCanBeClosed(currentEpochIndex);
        _closeCurrentEpoch(address(this));
    }

    function finalizeCurrentEpoch(
        uint256 currentEpochIndex,
        bytes32 postEpochOutputsRoot,
        bytes32[] calldata proof
    ) external override {
        bytes32 postEpochStateRoot;
        postEpochStateRoot = _preFinalize(currentEpochIndex, postEpochOutputsRoot, proof);
        _finalizeCurrentEpoch(postEpochStateRoot, postEpochOutputsRoot);
    }

    function getNumberOfValidators()
        public
        view
        override
        returns (uint8 numOfValidators)
    {
        numOfValidators = _NUM_OF_VALIDATORS;
    }

    function getValidatorIdByAddress(address validatorAddress)
        public
        view
        override
        returns (uint8 validatorId)
    {
        validatorId = _validatorIdByAddress[validatorAddress];
    }

    function getVoteBitmap(uint256 epochIndex, bytes32 postEpochStateRoot)
        public
        view
        override
        returns (bytes32 voteBitmap)
    {
        voteBitmap = _voteBitmaps[epochIndex][postEpochStateRoot];
    }

    function getAggregatedVoteBitmap(uint256 epochIndex)
        public
        view
        override
        returns (bytes32 aggregatedVoteBitmap)
    {
        aggregatedVoteBitmap = _aggregatedVoteBitmaps[epochIndex];
    }

    function vote(uint256 currentEpochIndex, bytes32 postEpochStateRoot)
        external
        override
    {
        address validatorAddress = msg.sender;
        uint8 validatorId = getValidatorIdByAddress(validatorAddress);
        require(validatorId != 0, MessageSenderIsNotValidator(validatorAddress));
        _validateCurrentEpochIndex(currentEpochIndex);
        bytes32 aggregatedVoteBitmap = getAggregatedVoteBitmap(currentEpochIndex);
        require(!aggregatedVoteBitmap.isBitSet(validatorId), VoteAlreadyCastForEpoch());
        bytes32 newAggregatedVoteBitmap = aggregatedVoteBitmap.setBitAt(validatorId);
        _aggregatedVoteBitmaps[currentEpochIndex] = newAggregatedVoteBitmap;
        bytes32 voteBitmap = getVoteBitmap(currentEpochIndex, postEpochStateRoot);
        bytes32 newVoteBitmap = voteBitmap.setBitAt(validatorId);
        _voteBitmaps[currentEpochIndex][postEpochStateRoot] = newVoteBitmap;
        emit Vote(currentEpochIndex, postEpochStateRoot, validatorAddress);
    }

    function _isPostEpochStateRootValid(bytes32 postEpochStateRoot)
        internal
        view
        override
        returns (bool)
    {
        bytes32 voteBitmap = getVoteBitmap(getCurrentEpochIndex(), postEpochStateRoot);
        uint256 voteCount = voteBitmap.countSetBits();
        return voteCount > getNumberOfValidators() / 2;
    }
}
