// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {EpochManagerImpl} from "./EpochManagerImpl.sol";
import {LibBitmap} from "../../library/LibBitmap.sol";
import {Quorum} from "../interfaces/Quorum.sol";

abstract contract QuorumImpl is EpochManagerImpl, Quorum {
    using LibBitmap for bytes32;

    uint8 immutable _NUM_OF_VALIDATORS;

    mapping(uint256 => address) private _validatorAddressById;
    mapping(address => uint8) private _validatorIdByAddress;
    mapping(uint256 => bytes32) private _aggregatedVoteBitmaps;
    mapping(uint256 => mapping(bytes32 => bytes32)) private _voteBitmaps;

    /// @notice Initialize the quorum.
    /// @param validators The array of validator addresses
    /// @dev If the validators array is empty, raises `NoValidator`.
    /// If the validator array has over 255 elements, raises `TooManyValidators`.
    constructor(address[] memory validators) {
        uint8 n;
        for (uint256 i; i < validators.length; ++i) {
            address validator = validators[i];
            if (_validatorIdByAddress[validator] == 0) {
                uint8 id = ++n; // reverts in case of overflow
                _validatorIdByAddress[validator] = id;
                _validatorAddressById[id] = validator;
            }
        }
        require(n >= 1, "quorum must not be empty");
        _NUM_OF_VALIDATORS = n;
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

    function getValidatorAddressById(uint256 validatorId)
        external
        view
        override
        returns (address validatorAddress)
    {
        validatorAddress = _validatorAddressById[validatorId];
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

    function vote(uint256 epochIndex, bytes32 postEpochStateRoot)
        external
        override
        isFirstNonFinalizedEpoch(epochIndex)
    {
        require(_isFirstNonFinalizedEpochClosed(), CannotCastVoteForOpenEpoch());

        // First, make sure the message sender is a validator.
        address validatorAddress = msg.sender;
        uint8 validatorId = getValidatorIdByAddress(validatorAddress);
        require(validatorId != 0, MessageSenderIsNotValidator(validatorAddress));

        // Second, check whether the validator has already voted in the epoch.
        // If not, mark the validator as having already voted in the epoch.
        {
            bytes32 bitmap = getAggregatedVoteBitmap(epochIndex);
            require(!bitmap.getBitAt(validatorId), VoteAlreadyCastForEpoch());
            bytes32 newBitmap = bitmap.setBitAt(validatorId);
            _aggregatedVoteBitmaps[epochIndex] = newBitmap;
        }

        // Third, mark the validator vote in the post-epoch state.
        {
            bytes32 bitmap = getVoteBitmap(epochIndex, postEpochStateRoot);
            bytes32 newBitmap = bitmap.setBitAt(validatorId);
            _voteBitmaps[epochIndex][postEpochStateRoot] = newBitmap;
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
        bytes32 bitmap = getVoteBitmap(epochIndex, postEpochStateRoot);
        uint256 voteCount = bitmap.countSetBits();
        return voteCount > getNumberOfValidators() / 2;
    }
}
