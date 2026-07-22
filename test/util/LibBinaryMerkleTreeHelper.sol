// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {CompressedNode} from "./CompressedNode.sol";

library LibBinaryMerkleTreeHelper {
    using LibBinaryMerkleTreeHelper for bytes32[];
    using LibBinaryMerkleTreeHelper for CompressedNode[];

    /// @notice The provided height is invalid.
    error InvalidHeight();

    /// @notice The provided node index is invalid.
    error InvalidNodeIndex();

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

    /// @notice Compute the root of a Merkle tree from a compressed array of nodes.
    /// @param compressedNodes The compressed array of Merkle tree nodes
    /// @param defaultNode The node used to right-pad the bottom level
    /// @param height The height of the Merkle tree
    /// @param nodeFromChildren The function that computes nodes from their children
    /// @return The root of the Merkle tree
    /// @dev Raises an `InvalidHeight` error if more than `2^height` nodes are provided.
    function merkleRootFromNodes(
        CompressedNode[] memory compressedNodes,
        bytes32 defaultNode,
        uint256 height,
        function(bytes32, bytes32) pure returns (bytes32) nodeFromChildren
    ) internal pure returns (bytes32) {
        for (uint256 i; i < height; ++i) {
            compressedNodes = compressedNodes.parentLevel(defaultNode, nodeFromChildren);
            defaultNode = nodeFromChildren(defaultNode, defaultNode);
        }
        require(compressedNodes.length <= 1, InvalidHeight());
        return compressedNodes.at(0, defaultNode);
    }

    /// @notice Compute the siblings of a node in a Merkle tree.
    /// @param nodes The nodes of Merkle tree
    /// @param defaultNode The node used to right-pad the bottom level
    /// @param nodeIndex The index of the node
    /// @param height The height of the Merkle tree
    /// @param nodeFromChildren The function that computes nodes from their children
    /// @return sibs The siblings of the node in bottom-up order
    /// @dev Raises an `InvalidNodeIndex` error if the provided index is out of bounds.
    /// @dev Raises an `InvalidHeight` error if more than `2^height` nodes are provided.
    function siblings(
        bytes32[] memory nodes,
        bytes32 defaultNode,
        uint256 nodeIndex,
        uint256 height,
        function(bytes32, bytes32) pure returns (bytes32) nodeFromChildren
    ) internal pure returns (bytes32[] memory sibs) {
        sibs = new bytes32[](height);
        for (uint256 i; i < height; ++i) {
            sibs[i] = nodes.at(nodeIndex ^ 1, defaultNode);
            nodes = nodes.parentLevel(defaultNode, nodeFromChildren);
            defaultNode = nodeFromChildren(defaultNode, defaultNode);
            nodeIndex >>= 1;
        }
        require(nodeIndex == 0, InvalidNodeIndex());
        require(nodes.length <= 1, InvalidHeight());
    }

    /// @notice Compute the siblings of a node in a Merkle tree from a compressed array of nodes.
    /// @param compressedNodes The compressed array of Merkle tree nodes
    /// @param defaultNode The node used to right-pad the bottom level
    /// @param nodeIndex The index of the node
    /// @param height The height of the Merkle tree
    /// @param nodeFromChildren The function that computes nodes from their children
    /// @return sibs The siblings of the node in bottom-up order
    /// @dev Raises an `InvalidNodeIndex` error if the provided index is out of bounds.
    /// @dev Raises an `InvalidHeight` error if more than `2^height` nodes are provided.
    function siblings(
        CompressedNode[] memory compressedNodes,
        bytes32 defaultNode,
        uint256 nodeIndex,
        uint256 height,
        function(bytes32, bytes32) pure returns (bytes32) nodeFromChildren
    ) internal pure returns (bytes32[] memory sibs) {
        sibs = new bytes32[](height);
        for (uint256 i; i < height; ++i) {
            sibs[i] = compressedNodes.at(nodeIndex ^ 1, defaultNode);
            compressedNodes = compressedNodes.parentLevel(defaultNode, nodeFromChildren);
            defaultNode = nodeFromChildren(defaultNode, defaultNode);
            nodeIndex >>= 1;
        }
        require(nodeIndex == 0, InvalidNodeIndex());
        require(decompressedLength(compressedNodes) <= 1, InvalidHeight());
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

    /// @notice Compute the length of the parent level of an array of compressed nodes.
    /// @param compressedNodes The compressed array of nodes
    /// @return len The number of compressed nodes on the parent level
    function parentLevelLength(CompressedNode[] memory compressedNodes)
        internal
        pure
        returns (uint256 len)
    {
        bool hasDanglingNode;
        for (uint256 i; i < compressedNodes.length; ++i) {
            if (hasDanglingNode) ++len;
            uint256 numFreeNodes = (hasDanglingNode ? 0 : 1) + compressedNodes[i].extra;
            if (numFreeNodes >= 2) ++len;
            hasDanglingNode = (numFreeNodes % 2 == 1);
        }
        if (hasDanglingNode) ++len;
    }

    /// @notice Compute the compressed parent level of an array of compressed nodes.
    /// @param compressedNodes The compressed array of nodes
    /// @param defaultNode The default node after the array
    /// @param nodeFromChildren The function that computes nodes from their children
    /// @return level The left-most compressed nodes of the parent level
    /// @dev The default node of a parent level is the parent node of two default nodes.
    function parentLevel(
        CompressedNode[] memory compressedNodes,
        bytes32 defaultNode,
        function(bytes32, bytes32) pure returns (bytes32) nodeFromChildren
    ) internal pure returns (CompressedNode[] memory level) {
        level = new CompressedNode[](parentLevelLength(compressedNodes));
        uint256 index;

        bool hasDanglingNode; // whether there is a dangling node
        bytes32 danglingValue; // dangling node value

        for (uint256 i; i < compressedNodes.length; ++i) {
            CompressedNode memory compressedNode = compressedNodes[i];
            bytes32 value = compressedNode.value;
            uint256 extra = compressedNode.extra;

            if (hasDanglingNode) {
                // If there is a dangling node, we can create a single compressed
                // node that combines this dangling node and one from the current
                // compressed node.
                bytes32 mixedNode = nodeFromChildren(danglingValue, value);
                level[index++] = compress(mixedNode, 0);
            }

            // Calculate the number of free nodes. If there was a dangling node,
            // then one of the nodes of the current compressed node was already
            // used. Either way, we have free 'extra' nodes to spare.
            uint256 numFreeNodes = (hasDanglingNode ? 0 : 1) + extra;

            // If there is at least 2 free nodes in the current compressed
            // node, we can create a compressed node combining them in pairs.
            if (numFreeNodes >= 2) {
                uint256 parentLength = numFreeNodes / 2;
                uint256 parentExtra = parentLength - 1;
                bytes32 parentNode = nodeFromChildren(value, value);
                level[index++] = compress(parentNode, parentExtra);
            }

            if (numFreeNodes % 2 == 1) {
                // If there is an odd number of free nodes, then one of them
                // becomes a dangling node for the next iteration.
                danglingValue = value;
                hasDanglingNode = true;
            } else {
                // If, otherwise, there is an even number of free nodes,
                // there is no dangling node for the next iteration.
                hasDanglingNode = false;
            }
        }

        if (hasDanglingNode) {
            // In the end, if there is still a dangling node, we can create a
            // single compressed node that combines this dangling node and the
            // default node value.
            bytes32 mixedNode = nodeFromChildren(danglingValue, defaultNode);
            level[index++] = compress(mixedNode, 0);
        }

        // Ensure we've reached the end of the array.
        assert(index == level.length);
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

    /// @notice Get the node at some index
    /// @param compressedNodes The compressed array of left-most nodes
    /// @param index The index of the node
    /// @param defaultNode The default node after the array
    function at(
        CompressedNode[] memory compressedNodes,
        uint256 index,
        bytes32 defaultNode
    ) internal pure returns (bytes32) {
        for (uint256 i; i < compressedNodes.length; ++i) {
            CompressedNode memory compressedNode = compressedNodes[i];
            if (index <= compressedNode.extra) {
                return compressedNode.value;
            } else {
                // We decrement the index by the length of the decompressed node
                // so that index now points past it, almost as an inductive step.
                index -= (1 + compressedNode.extra);
            }
        }
        return defaultNode;
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

    /// @notice Get the length of a decompressed array of nodes.
    /// @param compressedNodes The compressed array of nodes
    /// @return len The length of the (decompressed) array of nodes
    function decompressedLength(CompressedNode[] memory compressedNodes)
        internal
        pure
        returns (uint256 len)
    {
        for (uint256 i; i < compressedNodes.length; ++i) {
            len += (1 + compressedNodes[i].extra);
        }
    }

    /// @notice Uncompress an array of compressed nodes
    /// @param compressedNodes The compressed array of nodes
    /// @return nodes The (decompressed) array of nodes
    function decompress(CompressedNode[] memory compressedNodes)
        internal
        pure
        returns (bytes32[] memory nodes)
    {
        nodes = new bytes32[](decompressedLength(compressedNodes));
        uint256 index;
        for (uint256 i; i < compressedNodes.length; ++i) {
            for (uint256 j; j < 1 + compressedNodes[i].extra; ++j) {
                nodes[index++] = compressedNodes[i].value;
            }
        }
    }

    /// @notice Get the length of a compressed array of nodes.
    /// @param nodes The array of nodes
    /// @return len The length of the (compressed) array of nodes
    function compressedLength(bytes32[] memory nodes)
        internal
        pure
        returns (uint256 len)
    {
        if (nodes.length > 0) {
            ++len; // Add 1 compressed node for the first one
            for (uint256 i = 1; i < nodes.length; ++i) {
                if (nodes[i] != nodes[i - 1]) {
                    ++len; // Add 1 compressed node per border
                }
            }
        }
    }

    /// @notice Compress an array of nodes
    /// @param nodes The array of nodes
    /// @param compressedNodes The compressed array of nodes
    function compress(bytes32[] memory nodes)
        internal
        pure
        returns (CompressedNode[] memory compressedNodes)
    {
        compressedNodes = new CompressedNode[](compressedLength(nodes));
        if (nodes.length > 0) {
            uint256 index;
            compressedNodes[index].value = nodes[0]; // Initialize first node
            for (uint256 i = 1; i < nodes.length; ++i) {
                if (nodes[i] == compressedNodes[index].value) {
                    ++compressedNodes[index].extra; // Increment 'extra' count of node
                } else {
                    compressedNodes[++index].value = nodes[i]; // Initialize new node
                }
            }
        }
    }

    /// @notice Create a compressed node.
    /// @param value The compressed value
    /// @param extra The extra number of occurrences
    function compress(bytes32 value, uint256 extra)
        internal
        pure
        returns (CompressedNode memory)
    {
        return CompressedNode({value: value, extra: extra});
    }
}
