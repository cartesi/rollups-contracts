// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

library LibBinaryMerkleTreeHelper {
    using LibBinaryMerkleTreeHelper for bytes32[];

    /// @notice The provided node index is invalid.
    error InvalidNodeIndex();

    /// @notice The provided height is invalid.
    error InvalidHeight();

    /// @notice Compute the root of a Merkle tree from an array of nodes.
    /// @param nodes The nodes of Merkle tree
    /// @param defaultNode The node used to right-pad the bottom level
    /// @param height The height of the Merkle tree
    /// @param nodeFromChildren The function that computes nodes from their children
    /// @return The root of the Merkle tree
    /// @dev Raises an `InvalidHeight` error if more than `2^height` nodes are provided.
    function merkleRootFromNodes(
        bytes32[] memory nodes,
        bytes32 defaultNode,
        uint256 height,
        function(bytes32, bytes32) pure returns (bytes32) nodeFromChildren
    ) internal pure returns (bytes32) {
        for (uint256 i; i < height; ++i) {
            nodes = nodes.parentLevel(defaultNode, nodeFromChildren);
            defaultNode = nodeFromChildren(defaultNode, defaultNode);
        }
        require(nodes.length <= 1, InvalidHeight());
        return nodes.at(0, defaultNode);
    }

    /// @notice Compute the siblings of a node in a Merkle tree.
    /// @param nodes The nodes of Merkle tree
    /// @param defaultNode The node used to right-pad the bottom level
    /// @param nodeIndex The index of the node
    /// @param height The height of the Merkle tree
    /// @param nodeFromChildren The function that computes nodes from their children
    /// @return The siblings of the node in bottom-up order
    /// @dev Raises an `InvalidNodeIndex` error if the provided index is out of bounds.
    /// @dev Raises an `InvalidHeight` error if more than `2^height` nodes are provided.
    function siblings(
        bytes32[] memory nodes,
        bytes32 defaultNode,
        uint256 nodeIndex,
        uint256 height,
        function(bytes32, bytes32) pure returns (bytes32) nodeFromChildren
    ) internal pure returns (bytes32[] memory) {
        bytes32[] memory sibs = new bytes32[](height);
        for (uint256 i; i < height; ++i) {
            sibs[i] = nodes.at(nodeIndex ^ 1, defaultNode);
            nodes = nodes.parentLevel(defaultNode, nodeFromChildren);
            defaultNode = nodeFromChildren(defaultNode, defaultNode);
            nodeIndex >>= 1;
        }
        require(nodeIndex == 0, InvalidNodeIndex());
        require(nodes.length <= 1, InvalidHeight());
        return sibs;
    }

    /// @notice Compute the parent level of an array of nodes.
    /// @param nodes The array of left-most nodes
    /// @param defaultNode The default node after the array
    /// @param nodeFromChildren The function that computes nodes from their children
    /// @return The left-most nodes of the parent level
    /// @dev The default node of a parent level is
    /// the parent node of two default nodes.
    function parentLevel(
        bytes32[] memory nodes,
        bytes32 defaultNode,
        function(bytes32, bytes32) pure returns (bytes32) nodeFromChildren
    ) internal pure returns (bytes32[] memory) {
        uint256 n = (nodes.length + 1) / 2; // ceil(#nodes / 2)
        bytes32[] memory level = new bytes32[](n);
        for (uint256 i; i < n; ++i) {
            bytes32 leftChild = nodes[2 * i];
            bytes32 rightChild = nodes.at(2 * i + 1, defaultNode);
            level[i] = nodeFromChildren(leftChild, rightChild);
        }
        return level;
    }

    /// @notice Get the node at some index
    /// @param nodes The array of left-most nodes
    /// @param index The index of the node
    /// @param defaultNode The default node after the array
    function at(bytes32[] memory nodes, uint256 index, bytes32 defaultNode)
        internal
        pure
        returns (bytes32)
    {
        if (index < nodes.length) {
            return nodes[index];
        } else {
            return defaultNode;
        }
    }

    /// @notice Compute leaves from data blocks.
    /// @param dataBlocks The array of data blocks
    /// @param leafFromDataBlock The function that computes leaves from data blocks
    function toLeaves(
        bytes[] memory dataBlocks,
        function(bytes memory) pure returns (bytes32) leafFromDataBlock
    ) internal pure returns (bytes32[] memory leaves) {
        leaves = new bytes32[](dataBlocks.length);
        for (uint256 i; i < dataBlocks.length; ++i) {
            leaves[i] = leafFromDataBlock(dataBlocks[i]);
        }
    }

    /// @notice Splits a data buffer into equally-sized blocks.
    /// @param data The byte array
    /// @param dataBlockSize The data block size
    /// @return dataBlocks An array of data blocks.
    function splitIntoBlocks(bytes memory data, uint256 dataBlockSize)
        internal
        pure
        returns (bytes[] memory dataBlocks)
    {
        dataBlocks = new bytes[]((data.length + dataBlockSize - 1) / dataBlockSize);
        for (uint256 i; i < dataBlocks.length; ++i) {
            dataBlocks[i] = new bytes(dataBlockSize);
            uint256 offset = i * dataBlockSize;
            for (uint256 j; j < dataBlockSize; ++j) {
                if (offset + j < data.length) {
                    dataBlocks[i][j] = data[offset + j];
                }
            }
        }
    }
}
