// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {EpochManagerImpl} from "./EpochManagerImpl.sol";
import {LibTinyBitmap} from "../../library/LibTinyBitmap.sol";
import {Quorum} from "../interfaces/Quorum.sol";

abstract contract QuorumImpl is EpochManagerImpl, Quorum {
    using LibTinyBitmap for LibTinyBitmap.State;

    /// @notice No validator was provided.
    error NoValidator();

    /// @notice Too many validators were provided.
    error TooManyValidators();

    /// @notice A duplicated validator was provided.
    /// @param validator The duplicated validator
    error DuplicatedValidator(address validator);

    uint8 immutable _NUM_OF_VALIDATORS;

    mapping(address => uint8) private _validatorIdByAddress;
    mapping(uint256 => LibTinyBitmap.State) private _aggregatedVoteBitmaps;
    mapping(uint256 => mapping(bytes32 => LibTinyBitmap.State)) private _voteBitmaps;

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

    function closeEpoch(uint256 epochIndex) external override {
        canEpochBeClosed(epochIndex);
        _closeEpoch(address(this));
    }

    function finalizeEpoch(
        uint256 epochIndex,
        bytes32 postEpochOutputsRoot,
        bytes32[] calldata proof
    ) external override {
        bytes32 postEpochStateRoot;
        postEpochStateRoot = _preFinalize(epochIndex, postEpochOutputsRoot, proof);
        _finalizeEpoch(postEpochStateRoot, postEpochOutputsRoot);
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
        voteBitmap = _getVoteBitmap(epochIndex, postEpochStateRoot).toBytes32();
    }

    function getAggregatedVoteBitmap(uint256 epochIndex)
        public
        view
        override
        returns (bytes32 aggregatedVoteBitmap)
    {
        aggregatedVoteBitmap = _getAggregatedVoteBitmap(epochIndex).toBytes32();
    }

    function vote(uint256 epochIndex, bytes32 postEpochStateRoot)
        external
        override
        isFirstNonFinalizedEpoch(epochIndex)
    {
        // First, make sure the message sender is a validator.
        address validatorAddress = msg.sender;
        uint8 validatorId = getValidatorIdByAddress(validatorAddress);
        require(validatorId != 0, MessageSenderIsNotValidator(validatorAddress));

        // Second, check whether the validator has already voted in the epoch.
        // If not, mark the validator as having already voted in the epoch.
        {
            LibTinyBitmap.State storage epochBitmap;
            epochBitmap = _getAggregatedVoteBitmap(epochIndex);
            require(!epochBitmap.isBitSet(validatorId), VoteAlreadyCastForEpoch());
            epochBitmap.setBitAt(validatorId);
        }

        // Third, mark the validator vote in the post-epoch state.
        {
            LibTinyBitmap.State storage voteBitmap;
            voteBitmap = _getVoteBitmap(epochIndex, postEpochStateRoot);
            voteBitmap.setBitAt(validatorId);
        }

        // Finally, emit a Vote event.
        emit Vote(epochIndex, postEpochStateRoot, validatorAddress);
    }

    function _isPostEpochStateRootValid(bytes32 postEpochStateRoot)
        internal
        view
        override
        returns (bool)
    {
        uint256 epochIndex = getFinalizedEpochCount();
        LibTinyBitmap.State storage voteBitmap;
        voteBitmap = _getVoteBitmap(epochIndex, postEpochStateRoot);
        uint256 voteCount = voteBitmap.countSetBits();
        return voteCount > getNumberOfValidators() / 2;
    }

    /// @notice Get the vote bitmap state of an epoch and post-epoch state root.
    /// @param epochIndex The epoch index
    /// @param postEpochStateRoot The post-epoch state root
    /// @return state The bitmap state in storage
    function _getVoteBitmap(uint256 epochIndex, bytes32 postEpochStateRoot)
        internal
        view
        returns (LibTinyBitmap.State storage state)
    {
        state = _voteBitmaps[epochIndex][postEpochStateRoot];
    }

    /// @notice Get the aggregated vote bitmap state of an epoch.
    /// @param epochIndex The epoch index
    /// @return state The bitmap state in storage
    function _getAggregatedVoteBitmap(uint256 epochIndex)
        internal
        view
        returns (LibTinyBitmap.State storage state)
    {
        state = _aggregatedVoteBitmaps[epochIndex];
    }
}
