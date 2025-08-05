// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {EmulatorConstants} from "step/src/EmulatorConstants.sol";
import {Memory} from "step/src/Memory.sol";

import {Lib256Bitmap} from "../../library/Lib256Bitmap.sol";
import {LibBinaryMerkleTree} from "../../library/LibBinaryMerkleTree.sol";
import {LibKeccak256} from "../../library/LibKeccak256.sol";
import {Quorum} from "../interfaces/Quorum.sol";

abstract contract QuorumImpl is Quorum {
    using Lib256Bitmap for bytes32;
    using LibBinaryMerkleTree for bytes32[];

    /// @notice The quorum was already initialized.
    error AlreadyInitialized();

    /// @notice No validator was provided.
    error NoValidator();

    /// @notice Too many validators were provided.
    error TooManyValidators();

    /// @notice A duplicated validator was provided.
    /// @param validator The duplicated validator
    error DuplicatedValidator(address validator);

    uint256 constant TX_BUFFER_START = EmulatorConstants.PMA_CMIO_TX_BUFFER_START;
    uint256 constant LOG2_DATA_BLOCK_SIZE = EmulatorConstants.TREE_LOG2_WORD_SIZE;
    uint256 constant OUTPUTS_ROOT_LEAF_INDEX = TX_BUFFER_START >> LOG2_DATA_BLOCK_SIZE;

    uint256 private _currentEpochIndex;
    bool private _isCurrentEpochClosed;
    uint256 private _numberOfProcessedInputs;
    mapping(bytes32 => bool) private _isOutputsRootFinal;
    uint8 private _numOfValidators;
    mapping(address => uint8) private _validatorIdByAddress;
    mapping(uint256 => address) private _validatorAddressById;
    mapping(uint256 => bytes32) private _aggregatedVoteBitmaps;
    mapping(uint256 => mapping(bytes32 => bytes32)) private _voteBitmaps;

    /// @notice Initialize the quorum.
    /// @param validators The array of validator addresses
    /// @dev Should be called upon instantiation.
    /// If the quorum was already initialized, raises `AlreadyInitialized`.
    /// If the validators array is empty, raises `NoValidator`.
    /// If the validator array has over 255 elements, raises `TooManyValidators`.
    /// If the validator array has duplicate elements, raises `DuplicatedValidator`.
    function initQuorum(address[] calldata validators) external {
        require(_numOfValidators == 0, AlreadyInitialized());
        uint256 numOfValidators = validators.length;
        require(numOfValidators >= 1, NoValidator());
        require(numOfValidators <= 255, TooManyValidators());
        _numOfValidators = uint8(numOfValidators);
        for (uint256 i; i < numOfValidators; ++i) {
            address validator = validators[i];
            require(_validatorIdByAddress[validator] == 0, DuplicatedValidator(validator));
            uint8 id = uint8(i + 1);
            _validatorIdByAddress[validator] = id;
            _validatorAddressById[id] = validator;
        }
    }

    function getEpochFinalizerInterfaceId() external pure override returns (bytes4) {
        return type(Quorum).interfaceId;
    }

    function getCurrentEpochIndex() public view override returns (uint256) {
        return _currentEpochIndex;
    }

    function ensureCurrentEpochCanBeClosed(uint256 currentEpochIndex)
        public
        view
        override
    {
        _validateCurrentEpochIndex(currentEpochIndex);
        require(!_isCurrentEpochClosed, CannotCloseAlreadyClosedEpoch(currentEpochIndex));
        require(!_isOpenEpochEmpty(), CannotCloseEmptyEpoch(currentEpochIndex));
    }

    function closeCurrentEpoch(uint256 currentEpochIndex) external override {
        ensureCurrentEpochCanBeClosed(currentEpochIndex);
        _isCurrentEpochClosed = true;
        _numberOfProcessedInputs = _getNumberOfInputsBeforeCurrentBlock();
        emit EpochClosed(_currentEpochIndex, address(this));
    }

    function ensureCurrentEpochCanBeFinalized(
        uint256 currentEpochIndex,
        bytes32 postEpochOutputsRoot,
        bytes32[] calldata proof
    ) public view override {
        _preFinalize(currentEpochIndex, postEpochOutputsRoot, proof);
    }

    function finalizeCurrentEpoch(
        uint256 currentEpochIndex,
        bytes32 postEpochOutputsRoot,
        bytes32[] calldata proof
    ) external override {
        bytes32 postEpochStateRoot;
        postEpochStateRoot = _preFinalize(currentEpochIndex, postEpochOutputsRoot, proof);
        _currentEpochIndex = currentEpochIndex + 1;
        _isCurrentEpochClosed = false;
        _isOutputsRootFinal[postEpochOutputsRoot] = true;
        emit EpochFinalized(currentEpochIndex, postEpochStateRoot, postEpochOutputsRoot);
    }

    function isOutputsRootFinal(bytes32 outputsRoot)
        public
        view
        override
        returns (bool)
    {
        return _isOutputsRootFinal[outputsRoot];
    }

    function getNumberOfValidators()
        public
        view
        override
        returns (uint8 numOfValidators)
    {
        numOfValidators = _numOfValidators;
    }

    function getValidatorAddressById(uint8 validatorId)
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

    /// @notice Make sure the provided epoch index is the current epoch index.
    /// @param providedEpochIndex An epoch index
    /// @dev If the provided epoch index is not the current epoch index, raises `InvalidCurrentEpochIndex`.
    function _validateCurrentEpochIndex(uint256 providedEpochIndex) internal view {
        uint256 currentEpochIndex = getCurrentEpochIndex();
        require(
            providedEpochIndex == currentEpochIndex,
            InvalidCurrentEpochIndex(providedEpochIndex, currentEpochIndex)
        );
    }

    /// @notice Check whether the open epoch is empty.
    function _isOpenEpochEmpty() internal view returns (bool) {
        uint256 numberOfInputsBeforeCurrentBlock = _getNumberOfInputsBeforeCurrentBlock();
        assert(_numberOfProcessedInputs <= numberOfInputsBeforeCurrentBlock);
        return _numberOfProcessedInputs == numberOfInputsBeforeCurrentBlock;
    }

    /// @notice Similar to `ensureCurrentEpochCanBeFinalized` but returns post-epoch state root.
    /// @param currentEpochIndex The current epoch index
    /// @param postEpochOutputsRoot The post-epoch outputs root
    /// @param proof The Merkle proof for the post-epoch outputs root
    /// @return postEpochStateRoot The post-epoch state root
    function _preFinalize(
        uint256 currentEpochIndex,
        bytes32 postEpochOutputsRoot,
        bytes32[] calldata proof
    ) internal view returns (bytes32 postEpochStateRoot) {
        _validateCurrentEpochIndex(currentEpochIndex);
        _validateProofLength(proof.length);
        require(_isCurrentEpochClosed, CannotFinalizeOpenEpoch(currentEpochIndex));
        postEpochStateRoot = _computeStateRoot(postEpochOutputsRoot, proof);
        bytes32 voteBitmap = getVoteBitmap(currentEpochIndex, postEpochStateRoot);
        uint256 voteCount = voteBitmap.countSetBits();
        require(
            voteCount > getNumberOfValidators() / 2,
            InvalidPostEpochState(currentEpochIndex, postEpochStateRoot)
        );
    }

    /// @notice Make sure the provided proof length matches the expected proof length.
    /// @param proofLength The proof length
    /// @dev If the provided proof length is not valid, raises `InvalidOutputsRootProofLength`.
    function _validateProofLength(uint256 proofLength) internal pure {
        require(
            proofLength == Memory.LOG2_MAX_SIZE,
            InvalidOutputsRootProofLength(proofLength, Memory.LOG2_MAX_SIZE)
        );
    }

    /// @notice Compute the state root from an outputs root and a proof.
    /// @param outputsRoot The outputs root
    /// @param proof The outputs root proof
    /// @return The state root
    /// @dev Assumes the proof length is valid.
    function _computeStateRoot(bytes32 outputsRoot, bytes32[] calldata proof)
        internal
        pure
        returns (bytes32)
    {
        return proof.merkleRootAfterReplacement(
            OUTPUTS_ROOT_LEAF_INDEX,
            LibKeccak256.hashBytes(abi.encode(outputsRoot)),
            LibKeccak256.hashPair
        );
    }

    /// @notice Get the number of inputs before the current block.
    function _getNumberOfInputsBeforeCurrentBlock()
        internal
        view
        virtual
        returns (uint256);
}
