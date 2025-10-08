// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {LibBitmap} from "../../library/LibBitmap.sol";
import {OutboxImpl} from "../abstracts/OutboxImpl.sol";
import {QuorumApp} from "../interfaces/QuorumApp.sol";
import {Quorum} from "../interfaces/Quorum.sol";
import {TokenReceiverImpl} from "../abstracts/TokenReceiverImpl.sol";

contract QuorumAppImpl is QuorumApp, OutboxImpl, TokenReceiverImpl {
    using LibBitmap for bytes32;

    bytes32 immutable _GENESIS_STATE_ROOT;
    uint8 immutable _VALIDATOR_COUNT;

    mapping(uint256 => address) private _validatorAddressById;
    mapping(address => uint8) private _validatorIdByAddress;
    mapping(uint256 => bytes32) private _aggregatedVoteBitmaps;
    mapping(uint256 => mapping(bytes32 => bytes32)) private _voteBitmaps;

    /// @notice Constructs the QuorumAppImpl contract
    /// @param genesisStateRoot The genesis state root
    /// @param validators The validators array
    /// @dev If the validators array is empty, raises error.
    constructor(bytes32 genesisStateRoot, address[] memory validators) {
        _GENESIS_STATE_ROOT = genesisStateRoot;

        uint8 validatorCount;
        for (uint256 i; i < validators.length; ++i) {
            address validator = validators[i];
            if (_validatorIdByAddress[validator] == 0) {
                uint8 id = ++validatorCount; // reverts in case of overflow
                _validatorIdByAddress[validator] = id;
                _validatorAddressById[id] = validator;
            }
        }
        require(validatorCount >= 1, "quorum must not be empty");
        _VALIDATOR_COUNT = validatorCount;
    }

    function getGenesisStateRoot()
        public
        view
        override
        returns (bytes32 genesisStateRoot)
    {
        return _GENESIS_STATE_ROOT;
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

    function getValidatorCount() public view override returns (uint8 validatorCount) {
        validatorCount = _VALIDATOR_COUNT;
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
        return voteCount > getValidatorCount() / 2;
    }
}
