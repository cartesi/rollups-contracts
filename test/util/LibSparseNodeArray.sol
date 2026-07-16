// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {CompressedNode} from "./CompressedNode.sol";
import {SparseNode} from "./SparseNode.sol";

library LibSparseNodeArray {
    /// @notice A sparse node collides with another.
    error SparseNodeCollision(SparseNode sparseNode);

    /// @notice Converts an array of sparse nodes into an array of compressed nodes.
    /// @param sparseNodes The array of sparse nodes
    /// @param defaultValue The default value for nodes in-between sparse nodes
    /// @dev Useful for computing the root of trees with sparse nodes through
    /// LibBinaryMerkleTreeHelper functions for compressed nodes afterwards.
    /// This function is typed as external because it may raise a SparseNodeCollision
    /// error and the test contracts need to assume this error is not raised without
    /// having to wrap the function in an external library function. Also, the function
    /// sorts sparse nodes in-place, therefore making it external isolates the caller
    /// from this internal manipulation.
    function toCompressedNodeArray(SparseNode[] memory sparseNodes, bytes32 defaultValue)
        external
        pure
        returns (CompressedNode[] memory compressedNodes)
    {
        // First, we allocate the array of compressed nodes with the pre-computed length.
        compressedNodes = new CompressedNode[](_compressedNodeArrayLength(sparseNodes));

        uint256 nextIndexOnArray;
        uint256 nextIndexOnTree;

        // Next, for each sparse node, we push either 1 or 2 compressed nodes.
        for (uint256 i; i < sparseNodes.length; ++i) {
            SparseNode memory sparseNode = sparseNodes[i];

            // Check whether sparse node collides with any previous one.
            require(sparseNode.index >= nextIndexOnTree, SparseNodeCollision(sparseNode));

            // We compute the gap between the current sparse node and the next usable
            // index in the tree so that we can know how many compressed nodes we'll need.
            uint256 gap = sparseNode.index - nextIndexOnTree;

            // If there is any gap between the next usable slot and the current sparse
            // node, we fill it with the necessary number of default nodes.
            if (gap >= 1) {
                compressedNodes[nextIndexOnArray++] =
                    CompressedNode({value: defaultValue, extra: gap - 1});
            }

            // We then add the sparse node as a compressed node.
            compressedNodes[nextIndexOnArray++] =
                CompressedNode({value: sparseNode.value, extra: sparseNode.extra});

            // We update the next usable index in the tree.
            nextIndexOnTree = sparseNode.index + 1 + sparseNode.extra;
        }

        // Make sure that all the array was used.
        assert(nextIndexOnArray == compressedNodes.length);
    }

    /// @notice Compute the length of the compressed node array to be allocated.
    /// @param sparseNodes The array of sparse nodes
    /// @return len The length of the compressed node array
    /// @dev Orders the sparse node array in-place.
    function _compressedNodeArrayLength(SparseNode[] memory sparseNodes)
        internal
        pure
        returns (uint256 len)
    {
        uint256 nextIndexOnTree;

        _sortByIndexInPlace(sparseNodes);

        // For each sparse node, we decide whether we need to add 1 or 2 compressed nodes.
        for (uint256 i; i < sparseNodes.length; ++i) {
            SparseNode memory sparseNode = sparseNodes[i];

            // If there is a gap between the next usable index in the tree and the
            // current sparse node, then we need to add two compressed nodes
            // (one for the gap, and the other for the sparse node). Otherwise,
            // we just need to add one (the sparse node).
            len += (sparseNode.index > nextIndexOnTree) ? 2 : 1;

            // We update the next usable index for the next iteration.
            nextIndexOnTree = sparseNode.index + 1 + sparseNode.extra;
        }
    }

    /// @notice Sorts `sparseNodes` in ascending order of `index`, in place.
    /// @dev Insertion sort, O(n^2). Fine for small-to-medium arrays.
    function _sortByIndexInPlace(SparseNode[] memory sparseNodes) internal pure {
        for (uint256 i = 1; i < sparseNodes.length; i++) {
            SparseNode memory current = sparseNodes[i];
            uint256 j = i;

            // Shift every node with a larger index one slot to the right.
            // `j > 0` is checked before `j - 1`, so no underflow is possible.
            while (j > 0 && sparseNodes[j - 1].index > current.index) {
                sparseNodes[j] = sparseNodes[j - 1];
                j--;
            }

            sparseNodes[j] = current;
        }
    }
}
