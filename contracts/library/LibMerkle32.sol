// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

/// @title Merkle library for trees of 32-byte leaves
/// @notice This library is meant for creating and verifying Merkle proofs.
/// @notice Each Merkle tree is assumed to have `2^height` leaves.
/// @notice Nodes are concatenated pairwise and hashed with `keccak256`.
/// @notice Siblings are in bottom-up order, from leaf to root.
library LibMerkle32 {
    using LibMerkle32 for bytes32[];

    /// @notice Compute the root of a Merkle tree from its leaves.
    /// @param leaves The left-most leaves of the Merkle tree
    /// @param height The height of the Merkle tree
    /// @return The root hash of the Merkle tree
    /// @dev Raises an error if more than `2^height` leaves are provided.
    function merkleRoot(
        bytes32[] memory leaves,
        uint256 height
    ) internal pure returns (bytes32) {
        bytes32 defaultNode;
        for (uint256 i; i < height; ++i) {
            leaves = leaves.parentLevel(defaultNode);
            defaultNode = parent(defaultNode, defaultNode);
        }
        require(leaves.length <= 1, "LibMerkle32: too many leaves");
        return leaves.at(0, defaultNode);
    }

    /// @notice Compute the siblings of the ancestors of a leaf in a Merkle tree.
    /// @param leaves The left-most leaves of the Merkle tree
    /// @param index The index of the leaf
    /// @param height The height of the Merkle tree
    /// @return The siblings of the ancestors of the leaf in bottom-up order
    /// @dev Raises an error if the provided index is out of bounds.
    /// @dev Raises an error if more than `2^height` leaves are provided.
    function siblings(
        bytes32[] memory leaves,
        uint256 index,
        uint256 height
    ) internal pure returns (bytes32[] memory) {
        bytes32[] memory sibs = new bytes32[](height);
        bytes32 defaultNode;
        for (uint256 i; i < height; ++i) {
            sibs[i] = leaves.at(index ^ 1, defaultNode);
            leaves = leaves.parentLevel(defaultNode);
            defaultNode = parent(defaultNode, defaultNode);
            index >>= 1;
        }
        require(index == 0, "LibMerkle32: index out of bounds");
        require(leaves.length <= 1, "LibMerkle32: too many leaves");
        return sibs;
    }

    /// @notice Compute the root of a Merkle tree after replacing one of its leaves.
    /// @param sibs The siblings of the ancestors of the leaf in bottom-up order
    /// @param index The index of the leaf
    /// @param leaf The new leaf
    /// @return The root hash of the new Merkle tree
    /// @dev Raises an error if the provided index is out of bounds.
    function merkleRootAfterReplacement(
        bytes32[] calldata sibs,
        uint256 index,
        bytes32 leaf
    ) internal pure returns (bytes32) {
        uint256 height = sibs.length;
        for (uint256 i; i < height; ++i) {
            bytes32 sibling = sibs[i];
            if (index & 1 == 0) {
                leaf = parent(leaf, sibling);
            } else {
                leaf = parent(sibling, leaf);
            }
            index >>= 1;
        }
        require(index == 0, "LibMerkle32: index out of bounds");
        return leaf;
    }

    /// @notice Compute the parent of two nodes.
    /// @param leftNode The left node
    /// @param rightNode The right node
    /// @return parentNode The parent node
    /// @dev Uses assembly for extra performance
    function parent(
        bytes32 leftNode,
        bytes32 rightNode
    ) internal pure returns (bytes32 parentNode) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, leftNode)
            mstore(0x20, rightNode)
            parentNode := keccak256(0x00, 0x40)
        }
    }

    /// @notice Compute the parent level of an array of nodes.
    /// @param nodes The array of left-most nodes
    /// @param defaultNode The default node after the array
    /// @return The left-most nodes of the parent level
    /// @dev The default node of a parent level is
    /// the parent node of two default nodes.
    function parentLevel(
        bytes32[] memory nodes,
        bytes32 defaultNode
    ) internal pure returns (bytes32[] memory) {
        uint256 n = (nodes.length + 1) / 2; // ceil(#nodes / 2)
        bytes32[] memory level = new bytes32[](n);
        for (uint256 i; i < n; ++i) {
            bytes32 leftLeaf = nodes[2 * i];
            bytes32 rightLeaf = nodes.at(2 * i + 1, defaultNode);
            level[i] = parent(leftLeaf, rightLeaf);
        }
        return level;
    }

    /// @notice Get the node at some index
    /// @param nodes The array of left-most nodes
    /// @param index The index of the node
    /// @param defaultNode The default node after the array
    function at(
        bytes32[] memory nodes,
        uint256 index,
        bytes32 defaultNode
    ) internal pure returns (bytes32) {
        if (index < nodes.length) {
            return nodes[index];
        } else {
            return defaultNode;
        }
    }
}
