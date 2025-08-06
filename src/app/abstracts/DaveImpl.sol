// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {EmulatorConstants} from "step/src/EmulatorConstants.sol";
import {Memory} from "step/src/Memory.sol";

import {IDataProvider} from "prt-contracts/IDataProvider.sol";
import {ITournamentFactory} from "prt-contracts/ITournamentFactory.sol";
import {ITournament} from "prt-contracts/ITournament.sol";
import {Machine} from "prt-contracts/types/Machine.sol";

import {EpochManager} from "../interfaces/EpochManager.sol";
import {LibBinaryMerkleTree} from "../../library/LibBinaryMerkleTree.sol";
import {LibKeccak256} from "../../library/LibKeccak256.sol";

abstract contract DaveImpl is EpochManager, IDataProvider {
    using LibBinaryMerkleTree for bytes32[];
    using Machine for Machine.Hash;

    ITournamentFactory immutable _TOURNAMENT_FACTORY;

    uint256 private _currentEpochIndex;
    bool private _isCurrentEpochClosed;
    uint256 private _inputIndexInclusiveLowerBound;
    uint256 private _inputIndexExclusiveUpperBound;
    ITournament private _tournament;
    Machine.Hash private _lastFinalizedPostEpochStateRoot;
    mapping(bytes32 => bool) private _isOutputsRootFinal;

    uint256 constant TX_BUFFER_START = EmulatorConstants.PMA_CMIO_TX_BUFFER_START;
    uint256 constant LOG2_DATA_BLOCK_SIZE = EmulatorConstants.TREE_LOG2_WORD_SIZE;
    uint256 constant OUTPUTS_ROOT_LEAF_INDEX = TX_BUFFER_START >> LOG2_DATA_BLOCK_SIZE;

    constructor(ITournamentFactory tournamentFactory) {
        _TOURNAMENT_FACTORY = tournamentFactory;
    }

    function getEpochFinalizerInterfaceId() external pure override returns (bytes4) {
        return type(ITournament).interfaceId;
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
        _inputIndexInclusiveLowerBound = _inputIndexExclusiveUpperBound;
        _inputIndexExclusiveUpperBound = _getNumberOfInputsBeforeCurrentBlock();
        _tournament = _TOURNAMENT_FACTORY.instantiate(_getPreEpochStateRoot(), this);
        emit EpochClosed(_currentEpochIndex, address(_tournament));
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
        _lastFinalizedPostEpochStateRoot = Machine.Hash.wrap(postEpochStateRoot);
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

    function provideMerkleRootOfInput(uint256 inputIndexWithinEpoch, bytes calldata)
        external
        view
        override
        returns (bytes32)
    {
        uint256 inputIndex = _inputIndexInclusiveLowerBound + inputIndexWithinEpoch;

        if (inputIndex >= _inputIndexExclusiveUpperBound) {
            // out-of-bounds index: repeat the state (as a fixpoint function)
            return bytes32(0);
        }

        return _getInputMerkleRoot(inputIndex);
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
        assert(_inputIndexExclusiveUpperBound <= numberOfInputsBeforeCurrentBlock);
        return _inputIndexExclusiveUpperBound == numberOfInputsBeforeCurrentBlock;
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
        bool isFinished;
        Machine.Hash finalMachineStateHash;
        (isFinished,, finalMachineStateHash) = _tournament.arbitrationResult();
        require(
            isFinished && Machine.Hash.wrap(postEpochStateRoot).eq(finalMachineStateHash),
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

    /// @notice Get the pre-epoch state root.
    function _getPreEpochStateRoot() internal view returns (Machine.Hash) {
        if (_currentEpochIndex == 0) {
            return _getGenesisStateRoot();
        } else {
            return _lastFinalizedPostEpochStateRoot;
        }
    }

    /// @notice Get the number of inputs before the current block.
    function _getNumberOfInputsBeforeCurrentBlock()
        internal
        view
        virtual
        returns (uint256);

    /// @notice Get the Merkle root of an input by its index.
    /// @param inputIndex The input index
    function _getInputMerkleRoot(uint256 inputIndex)
        internal
        view
        virtual
        returns (bytes32);

    /// @notice Get the genesis state root.
    function _getGenesisStateRoot() internal view virtual returns (Machine.Hash);
}
