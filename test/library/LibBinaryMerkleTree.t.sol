// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Test} from "forge-std-1.9.6/src/Test.sol";

import {LibMath} from "src/library/LibMath.sol";
import {LibKeccak256} from "src/library/LibKeccak256.sol";
import {LibBinaryMerkleTree} from "src/library/LibBinaryMerkleTree.sol";

import {LibBinaryMerkleTreeHelper} from "../util/LibBinaryMerkleTreeHelper.sol";

library ExternalLibBinaryMerkleTree {
    function merkleRootAfterReplacement(
        bytes32[] calldata sibs,
        uint256 nodeIndex,
        bytes32 node
    ) external pure returns (bytes32) {
        return LibBinaryMerkleTree.merkleRootAfterReplacement(
            sibs, nodeIndex, node, nodeFromChildren
        );
    }

    function merkleRoot(
        bytes memory data,
        uint256 log2DriveSize,
        uint256 log2DataBlockSize
    ) external pure returns (bytes32) {
        return LibBinaryMerkleTree.merkleRoot(
            data, log2DriveSize, log2DataBlockSize, leafFromDataAt, nodeFromChildren
        );
    }

    function merkleRootFromNodes(
        bytes32[] memory nodes,
        bytes32 defaultNode,
        uint256 height
    ) external pure returns (bytes32) {
        return LibBinaryMerkleTreeHelper.merkleRootFromNodes(
            nodes, defaultNode, height, nodeFromChildren
        );
    }

    function siblings(
        bytes32[] memory nodes,
        bytes32 defaultNode,
        uint256 nodeIndex,
        uint256 height
    ) external pure returns (bytes32[] memory) {
        return LibBinaryMerkleTreeHelper.siblings(
            nodes, defaultNode, nodeIndex, height, nodeFromChildren
        );
    }

    function parentLevel(bytes32[] memory nodes, bytes32 defaultNode)
        external
        pure
        returns (bytes32[] memory)
    {
        return LibBinaryMerkleTreeHelper.parentLevel(nodes, defaultNode, nodeFromChildren);
    }

    function toLeaves(bytes[] memory dataBlocks)
        external
        pure
        returns (bytes32[] memory leaves)
    {
        return LibBinaryMerkleTreeHelper.toLeaves(dataBlocks, leafFromDataBlock);
    }

    function splitIntoBlocks(bytes memory data, uint256 dataBlockSize)
        external
        pure
        returns (bytes[] memory dataBlocks)
    {
        return LibBinaryMerkleTreeHelper.splitIntoBlocks(data, dataBlockSize);
    }

    function leafFromDataBlock(bytes memory data) internal pure returns (bytes32 leaf) {
        return LibKeccak256.hashBytes(data);
    }

    function leafFromDataAt(
        bytes memory data,
        uint256 dataBlockIndex,
        uint256 dataBlockSize
    ) internal pure returns (bytes32 leaf) {
        return LibKeccak256.hashBlock(data, dataBlockIndex, dataBlockSize);
    }

    function nodeFromChildren(bytes32 leaf, bytes32 right)
        internal
        pure
        returns (bytes32 node)
    {
        return LibKeccak256.hashPair(leaf, right);
    }
}

contract LibBinaryMerkleTreeTest is Test {
    using ExternalLibBinaryMerkleTree for bytes32[];
    using ExternalLibBinaryMerkleTree for bytes[];
    using ExternalLibBinaryMerkleTree for bytes;
    using LibMath for uint256;

    // --------------
    // test functions
    // --------------

    function testMerkleRootAfterReplacement(
        bytes32[] memory nodes,
        uint256 height,
        uint256 nodeIndex,
        bytes32 defaultNode,
        bytes32 newNode
    ) external pure {
        // Bound height and nodeIndex parameters according to the number of nodes
        height = _boundHeight(height, nodes.length);
        nodeIndex = _boundBits(nodeIndex, height);

        // Get node at given index or use default node if beyond array bounds
        bytes32 node = (nodeIndex < nodes.length) ? nodes[nodeIndex] : defaultNode;

        // Compute the Merkle root from the nodes
        bytes32 rootFromNodes = nodes.merkleRootFromNodes(defaultNode, height);

        // Compute the siblings of the node
        bytes32[] memory siblings = nodes.siblings(defaultNode, nodeIndex, height);

        // Compute the Merkle root from the siblings
        bytes32 rootFromSiblings = siblings.merkleRootAfterReplacement(nodeIndex, node);

        // Ensure the two Merkle roots match
        assertEq(rootFromNodes, rootFromSiblings);

        if (nodeIndex < nodes.length) {
            // If node is within array bounds, replace node
            nodes[nodeIndex] = newNode;

            // Compute the new Merkle root from the nodes
            rootFromNodes = nodes.merkleRootFromNodes(defaultNode, height);

            // Compute the new Merkle root from the same siblings but new node
            rootFromSiblings = siblings.merkleRootAfterReplacement(nodeIndex, newNode);

            // Ensure the two new Merkle roots also match
            assertEq(rootFromNodes, rootFromSiblings);
        }
    }

    function testMerkleRootAfterReplacementRevertsInvalidNodeIndex(
        bytes32[] memory siblings,
        uint256 nodeIndex,
        bytes32 node
    ) external {
        // First, make sure the tree has less than 2^256 leaves,
        // otherwise every unsigned 256-bit node index would be valid.
        uint256 height = siblings.length;
        vm.assume(height < 256);

        // Second, bound the node index to beyond the number
        // of leaves in the tree, based on the tree height.
        nodeIndex = bound(nodeIndex, 1 << height, type(uint256).max);

        // Finally, provide the invalid node index to the
        // merkleRootAfterReplacement function and expect an error.
        vm.expectRevert(LibBinaryMerkleTree.InvalidNodeIndex.selector);
        siblings.merkleRootAfterReplacement(nodeIndex, node);
    }

    function testMerkleRoot(
        bytes memory data,
        uint256 log2DriveSize,
        uint256 log2DataBlockSize,
        uint256 log2LeavesToReplace,
        bytes32 replacementDataSeed,
        uint256 replacementNodeIndex
    ) external pure {
        // First, compute the smallest log2 drive size that would fit the data.
        uint256 minLog2DriveSize = data.length.ceilLog2();

        // Second, we bound the log2 drive size to between the minimum amount
        // calculated in the previous step and the maximum allowed.
        uint256 maxLog2DriveSize = LibBinaryMerkleTree.LOG2_MAX_DRIVE_SIZE;
        log2DriveSize = bound(log2DriveSize, minLog2DriveSize, maxLog2DriveSize);

        // Third, we bound the log2 data block size between 0 and
        // the minimum between log2 drive size and the maximum allowed.
        uint256 maxLog2DataBlockSize = LibBinaryMerkleTree.LOG2_MAX_DATA_BLOCK_SIZE;
        maxLog2DataBlockSize = maxLog2DataBlockSize.min(log2DriveSize);
        log2DataBlockSize = bound(log2DataBlockSize, 0, maxLog2DataBlockSize);

        // Finally, we compute the root of the Merkle tree from the data
        bytes32 rootFromData = data.merkleRoot(log2DriveSize, log2DataBlockSize);

        // Now, we take an alternative approach.
        // First, we slice the data into blocks with the same size we used before.
        uint256 dataBlockSize = 1 << log2DataBlockSize;
        bytes[] memory dataBlocks = data.splitIntoBlocks(dataBlockSize);

        // Then, we compute the leaves from these data blocks
        bytes32[] memory leaves = dataBlocks.toLeaves();

        // Then, we compute the Merkle root from the leaves
        uint256 height = log2DriveSize - log2DataBlockSize;
        bytes memory pristineDataBlock = new bytes(dataBlockSize);
        bytes32 pristineLeaf = pristineDataBlock.leafFromDataBlock();
        bytes32 rootFromLeaves = leaves.merkleRootFromNodes(pristineLeaf, height);

        // Ensure that Merkle roots match
        assertEq(rootFromData, rootFromLeaves);

        // Now, we want to replace a part of the data and be able to reconstruct
        // the new Merkle root in two ways: from the updated data buffer and
        // by constructing the Merkle root bottom-up through a replacement proof.

        // First, we need to make sure that the data spans at least one full block.
        // Otherwise, we won't be able to replace a full block from it.
        uint256 numOfFullDataBlocks = data.length >> log2DataBlockSize;
        vm.assume(numOfFullDataBlocks > 0);

        // Then we compute the floor log2 number of full data blocks.
        // This will help us bound the log2 number of leaves and log2 replacement size.
        uint256 maxLog2LeavesToReplace = numOfFullDataBlocks.floorLog2();
        log2LeavesToReplace = bound(log2LeavesToReplace, 0, maxLog2LeavesToReplace);
        uint256 log2ReplacementSize = log2LeavesToReplace + log2DataBlockSize;

        // Calculate replacement size and allocate buffer for replacement data
        uint256 replacementSize = 1 << log2ReplacementSize;
        bytes memory replacementData = new bytes(replacementSize);

        // Fill the replacement data buffer with random bytes derived from the seed
        for (uint256 i; i < replacementData.length; ++i) {
            replacementData[i] = bytes1(keccak256(abi.encode(replacementDataSeed, i)));
        }

        // Compute the replacement Merkle root from the replacement data
        bytes32 replacementRootFromData =
            replacementData.merkleRoot(log2ReplacementSize, log2DataBlockSize);

        // Bound the replacement node index by the number of replaceable nodes
        uint256 numOfReplaceableNodes = data.length >> log2ReplacementSize;
        assertGe(numOfReplaceableNodes, 1, "expected at least one replaceable node");
        replacementNodeIndex = bound(replacementNodeIndex, 0, numOfReplaceableNodes - 1);

        // Make sure replacement is completely within the boundaries of the data
        assertLe(((replacementNodeIndex + 1) << log2ReplacementSize), data.length);

        // Compute the siblings of the to-be-replaced node by computing the
        // siblings of the first leaf of the to-be-replaced Merkle tree.
        uint256 firstReplacementLeafIndex = replacementNodeIndex << log2LeavesToReplace;
        bytes32[] memory replacedLeafSiblings =
            leaves.siblings(pristineLeaf, firstReplacementLeafIndex, height);

        // Allocate a siblings array for the replacement node
        bytes32[] memory replacementNodeSiblings =
            new bytes32[](log2DriveSize - log2ReplacementSize);

        // Copy the siblings from the replacement leaf after a given height
        assertEq(
            replacementNodeSiblings.length + log2LeavesToReplace,
            replacedLeafSiblings.length,
            "siblings array difference doesn't match expected difference"
        );
        for (uint256 i; i < replacementNodeSiblings.length; ++i) {
            assertLt(
                i + log2LeavesToReplace,
                replacedLeafSiblings.length,
                "buffer overrun while copying siblings"
            );
            replacementNodeSiblings[i] = replacedLeafSiblings[i + log2LeavesToReplace];
        }

        // From the siblings array, node index, and replacement root,
        // we can compute the updated Merkle root
        bytes32 updatedRootFromSiblings = replacementNodeSiblings
            .merkleRootAfterReplacement(replacementNodeIndex, replacementRootFromData);

        // Now we write the replacement onto the data buffer
        for (uint256 i; i < replacementSize; ++i) {
            uint256 offset = replacementNodeIndex << log2ReplacementSize;
            assertLt(
                offset + i,
                data.length,
                "buffer overrun while writing replacement over data buffer"
            );
            data[offset + i] = replacementData[i];
        }

        // Compute new Merkle root from the updated data
        bytes32 updatedRootFromData = data.merkleRoot(log2DriveSize, log2DataBlockSize);

        // Ensure Merkle roots match (from data and from siblings)
        assertEq(updatedRootFromData, updatedRootFromSiblings);
    }

    function testMerkleRootRevertsDriveTooLarge(
        bytes memory data,
        uint256 log2DriveSize,
        uint256 log2DataBlockSize
    ) external {
        // First, we bound the log2 drive size to beyond the maximum.
        uint256 maxLog2DriveSize = LibBinaryMerkleTree.LOG2_MAX_DRIVE_SIZE;
        log2DriveSize = bound(log2DriveSize, maxLog2DriveSize + 1, type(uint256).max);

        // Then, we call the merkleRoot function and expect an error.
        vm.expectRevert(LibBinaryMerkleTree.DriveTooLarge.selector);
        data.merkleRoot(log2DriveSize, log2DataBlockSize);
    }

    function testMerkleRootRevertsDataBlockTooLarge(
        bytes memory data,
        uint256 log2DriveSize,
        uint256 log2DataBlockSize
    ) external {
        // First, compute the smallest log2 drive size that would fit the data.
        uint256 minLog2DriveSize = data.length.ceilLog2();

        // Second, we bound the log2 drive size to between the minimum amount
        // calculated in the previous step and the maximum allowed.
        uint256 maxLog2DriveSize = LibBinaryMerkleTree.LOG2_MAX_DRIVE_SIZE;
        log2DriveSize = bound(log2DriveSize, minLog2DriveSize, maxLog2DriveSize);

        // Third, we bound the log2 data block size beyond the maximum allowed.
        uint256 maxLog2DataBlockSize = LibBinaryMerkleTree.LOG2_MAX_DATA_BLOCK_SIZE;
        log2DataBlockSize =
            bound(log2DataBlockSize, maxLog2DataBlockSize + 1, type(uint256).max);

        // Then, we call the merkleRoot function and expect an error.
        vm.expectRevert(LibBinaryMerkleTree.DataBlockTooLarge.selector);
        data.merkleRoot(log2DriveSize, log2DataBlockSize);
    }

    function testMerkleRootRevertsDriveSmallerThanData(
        bytes memory data,
        uint256 log2DriveSize,
        uint256 log2DataBlockSize
    ) external {
        // First, we assume that the data is not empty or
        // has a single byte, otherwise every drive (having
        // its size described in log2) would fit it.
        vm.assume(data.length > 1);

        // Second, compute the smallest log2 drive size that would
        // fit the data. This will important to force the
        // DriveSmallerThanData error.
        uint256 minLog2DriveSize = data.length.ceilLog2();

        // Ensure the smallest log2 drive size is greater
        // than zero so that we can subtract 1 from it.
        assertGt(minLog2DriveSize, 0);

        // Third, bound the log2 drive size between zero
        // and the maximum invalid value.
        log2DriveSize = bound(log2DriveSize, 0, minLog2DriveSize - 1);

        // Fourth, we bound the log2 data block size between 0 and
        // the minimum between log2 drive size and the maximum allowed.
        uint256 maxLog2DataBlockSize = LibBinaryMerkleTree.LOG2_MAX_DATA_BLOCK_SIZE;
        maxLog2DataBlockSize = maxLog2DataBlockSize.min(log2DriveSize);
        log2DataBlockSize = bound(log2DataBlockSize, 0, maxLog2DataBlockSize);

        // Then, we call the merkleRoot function and expect an error.
        vm.expectRevert(LibBinaryMerkleTree.DriveSmallerThanData.selector);
        data.merkleRoot(log2DriveSize, log2DataBlockSize);
    }

    // ------------------
    // internal functions
    // ------------------

    /// @notice Compute a Merkle tree leaf from a data block.
    /// @param data The data
    /// @param dataBlockIndex The data block index
    /// @param dataBlockSize The data block size
    function _leafFromDataBlock(
        bytes memory data,
        uint256 dataBlockIndex,
        uint256 dataBlockSize
    ) internal pure returns (bytes32 leaf) {
        return data.leafFromDataAt(dataBlockIndex, dataBlockSize);
    }

    /// @notice Compute a Merkle tree node from its children.
    /// @param left The left child
    /// @param right The right child
    /// @return node The node with the provided left and right children
    function _nodeFromChildren(bytes32 left, bytes32 right)
        internal
        pure
        returns (bytes32 node)
    {
        return ExternalLibBinaryMerkleTree.nodeFromChildren(left, right);
    }

    /// @notice Bounds a value between `y` (inclusive) and 256 (inclusive),
    /// where `y` is the smallest unsigned integer such that `n <= 2^y`.
    /// @param height The random seed
    /// @param n The value `n` in the expression
    /// @return newHeight A value `y` such that `n <= 2^y`
    function _boundHeight(uint256 height, uint256 n)
        internal
        pure
        returns (uint256 newHeight)
    {
        return bound(height, LibMath.ceilLog2(n), 256);
    }

    /// @notice Bounds a value between `0` (inclusive) and `2^{nbits}` (exclusive).
    /// @param x The random seed
    /// @param nbits The number of non-zero least-significant bits
    /// @return newValue A value between 0 and `2^{nbits}`
    function _boundBits(uint256 x, uint256 nbits)
        internal
        pure
        returns (uint256 newValue)
    {
        if (nbits < 256) {
            return x >> (256 - nbits);
        } else {
            return x;
        }
    }
}
