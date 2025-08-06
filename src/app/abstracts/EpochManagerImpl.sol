// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {CanonicalMachine} from "../../common/CanonicalMachine.sol";
import {EpochManager} from "../interfaces/EpochManager.sol";
import {LibBinaryMerkleTree} from "../../library/LibBinaryMerkleTree.sol";
import {LibKeccak256} from "../../library/LibKeccak256.sol";

abstract contract EpochManagerImpl is EpochManager {
    using LibBinaryMerkleTree for bytes32[];

    uint256 private _currentEpochIndex;
    bool _isCurrentEpochClosed;
    uint256 private _inputIndexInclusiveLowerBound;
    uint256 private _inputIndexExclusiveUpperBound;
    mapping(bytes32 => bool) private _isOutputsRootFinal;

    function getCurrentEpochIndex()
        public
        view
        override
        returns (uint256 currentEpochIndex)
    {
        return _currentEpochIndex;
    }

    function isOutputsRootFinal(bytes32 outputsRoot)
        public
        view
        override
        returns (bool)
    {
        return _isOutputsRootFinal[outputsRoot];
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

    function ensureCurrentEpochCanBeFinalized(
        uint256 currentEpochIndex,
        bytes32 postEpochOutputsRoot,
        bytes32[] calldata proof
    ) public view override {
        _preFinalize(currentEpochIndex, postEpochOutputsRoot, proof);
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

    /// @notice Close the current epoch.
    function _closeCurrentEpoch(address epochFinalizer) internal {
        _isCurrentEpochClosed = true;
        _inputIndexInclusiveLowerBound = _inputIndexExclusiveUpperBound;
        _inputIndexExclusiveUpperBound = _getNumberOfInputsBeforeCurrentBlock();
        emit EpochClosed(getCurrentEpochIndex(), epochFinalizer);
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
        require(
            _isPostEpochStateRootValid(postEpochStateRoot),
            InvalidPostEpochState(currentEpochIndex, postEpochStateRoot)
        );
    }

    /// @notice Finalize the current epoch.
    function _finalizeCurrentEpoch(
        bytes32 postEpochStateRoot,
        bytes32 postEpochOutputsRoot
    ) internal {
        uint256 currentEpochIndex = _currentEpochIndex;
        _currentEpochIndex = currentEpochIndex + 1;
        _isCurrentEpochClosed = false;
        _isOutputsRootFinal[postEpochOutputsRoot] = true;
        emit EpochFinalized(currentEpochIndex, postEpochStateRoot, postEpochOutputsRoot);
    }

    /// @notice Make sure the provided proof length matches the expected proof length.
    /// @param proofLength The proof length
    /// @dev If the provided proof length is not valid, raises `InvalidOutputsRootProofLength`.
    function _validateProofLength(uint256 proofLength) internal pure {
        require(
            proofLength == CanonicalMachine.TREE_HEIGHT,
            InvalidOutputsRootProofLength(proofLength, CanonicalMachine.TREE_HEIGHT)
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
            CanonicalMachine.OUTPUTS_ROOT_LEAF_INDEX,
            LibKeccak256.hashBytes(abi.encode(outputsRoot)),
            LibKeccak256.hashPair
        );
    }

    /// @notice Get the input index inclusive lower bound.
    function _getInputIndexInclusiveLowerBound()
        internal
        view
        returns (uint256 inputIndexInclusiveLowerBound)
    {
        return _inputIndexInclusiveLowerBound;
    }

    /// @notice Get the input index exclusive upper bound.
    function _getInputIndexExclusiveUpperBound()
        internal
        view
        returns (uint256 inputIndexExclusiveUpperBound)
    {
        return _inputIndexExclusiveUpperBound;
    }

    /// @notice Get the number of inputs before the current block.
    function _getNumberOfInputsBeforeCurrentBlock()
        internal
        view
        virtual
        returns (uint256);

    /// @notice Check whether the current (closed) epoch can be
    /// finalized with the given post-epoch state root.
    /// @param postEpochStateRoot The post-epoch state root
    /// @return Whether the current (closed) epoch can be finalized
    /// with the given post-epoch state root.
    function _isPostEpochStateRootValid(bytes32 postEpochStateRoot)
        internal
        view
        virtual
        returns (bool);
}
