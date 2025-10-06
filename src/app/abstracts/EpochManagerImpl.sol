// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {CanonicalMachine} from "../../common/CanonicalMachine.sol";
import {EpochManager} from "../interfaces/EpochManager.sol";
import {InboxImpl} from "./InboxImpl.sol";
import {LibBinaryMerkleTree} from "../../library/LibBinaryMerkleTree.sol";
import {LibKeccak256} from "../../library/LibKeccak256.sol";

abstract contract EpochManagerImpl is EpochManager, InboxImpl {
    using LibBinaryMerkleTree for bytes32[];

    uint256 private _finalizedEpochCount;
    bool private __isFirstNonFinalizedEpochClosed;
    uint256 private _inputIndexInclusiveLowerBound;
    uint256 private _inputIndexExclusiveUpperBound;
    mapping(bytes32 => bool) private _isOutputsRootFinal;

    function getFinalizedEpochCount()
        public
        view
        override
        returns (uint256 finalizedEpochCount)
    {
        return _finalizedEpochCount;
    }

    function isOutputsRootFinal(bytes32 outputsRoot)
        public
        view
        override
        returns (bool isFinal)
    {
        return _isOutputsRootFinal[outputsRoot];
    }

    modifier isFirstNonFinalizedEpoch(uint256 epochIndex) {
        _validateEpochIndex(epochIndex);
        _;
    }

    function canEpochBeClosed(uint256 epochIndex)
        public
        view
        override
        isFirstNonFinalizedEpoch(epochIndex)
    {
        require(!_isFirstNonFinalizedEpochClosed(), EpochAlreadyClosed(epochIndex));
        require(!_isOpenEpochEmpty(), CannotCloseEmptyEpoch(epochIndex));
    }

    function canEpochBeFinalized(
        uint256 epochIndex,
        bytes32 postEpochOutputsRoot,
        bytes32[] calldata proof
    ) public view override {
        _preFinalize(epochIndex, postEpochOutputsRoot, proof);
    }

    /// @notice Make sure the provided epoch index is the first non-finalized epoch index.
    /// @param providedEpochIndex An epoch index
    /// @dev If the provided epoch index is not valid, raises `NotFirstNonFinalizedEpoch`.
    function _validateEpochIndex(uint256 providedEpochIndex) internal view {
        uint256 expectedEpochIndex = getFinalizedEpochCount();
        require(
            providedEpochIndex == expectedEpochIndex,
            NotFirstNonFinalizedEpoch(providedEpochIndex)
        );
    }

    /// @notice Check whether the open epoch is empty.
    function _isOpenEpochEmpty() internal view returns (bool) {
        uint256 inputCountBeforeCurrentBlock = getInputCountBeforeCurrentBlock();
        assert(_inputIndexExclusiveUpperBound <= inputCountBeforeCurrentBlock);
        return _inputIndexExclusiveUpperBound == inputCountBeforeCurrentBlock;
    }

    /// @notice Close the first non-finalized epoch.
    function _closeEpoch(address epochFinalizer) internal {
        __isFirstNonFinalizedEpochClosed = true;
        _inputIndexInclusiveLowerBound = _inputIndexExclusiveUpperBound;
        _inputIndexExclusiveUpperBound = getInputCountBeforeCurrentBlock();
        uint256 epochIndex = getFinalizedEpochCount();
        emit EpochClosed(epochIndex, epochFinalizer);
    }

    /// @notice Similar to `canEpochBeFinalized` but returns post-epoch state root.
    /// @param epochIndex The epoch index
    /// @param postEpochOutputsRoot The post-epoch outputs root
    /// @param proof The Merkle proof for the post-epoch outputs root
    /// @return postEpochStateRoot The post-epoch state root
    function _preFinalize(
        uint256 epochIndex,
        bytes32 postEpochOutputsRoot,
        bytes32[] calldata proof
    )
        internal
        view
        isFirstNonFinalizedEpoch(epochIndex)
        returns (bytes32 postEpochStateRoot)
    {
        _validateProofLength(proof.length);
        require(_isFirstNonFinalizedEpochClosed(), CannotFinalizeOpenEpoch(epochIndex));
        postEpochStateRoot = _computeStateRoot(postEpochOutputsRoot, proof);
        require(
            _isPostEpochStateRootValid(postEpochStateRoot),
            InvalidPostEpochState(epochIndex, postEpochStateRoot)
        );
    }

    /// @notice Finalize the first non-finalized epoch.
    function _finalizeEpoch(bytes32 postEpochStateRoot, bytes32 postEpochOutputsRoot)
        internal
    {
        uint256 epochIndex = _finalizedEpochCount;
        _finalizedEpochCount = epochIndex + 1;
        __isFirstNonFinalizedEpochClosed = false;
        _isOutputsRootFinal[postEpochOutputsRoot] = true;
        emit EpochFinalized(epochIndex, postEpochStateRoot, postEpochOutputsRoot);
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

    /// @notice Check whether the first non-finalized epoch is closed.
    function _isFirstNonFinalizedEpochClosed()
        internal
        view
        returns (bool isFirstNonFinalizedEpochClosed)
    {
        return __isFirstNonFinalizedEpochClosed;
    }

    /// @notice Check whether the first non-finalized epoch
    /// can be finalized with the given post-epoch state root.
    /// @param postEpochStateRoot The post-epoch state root
    function _isPostEpochStateRootValid(bytes32 postEpochStateRoot)
        internal
        view
        virtual
        returns (bool);
}
