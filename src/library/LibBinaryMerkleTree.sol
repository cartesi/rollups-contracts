// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

library LibBinaryMerkleTree {
    /// @notice The provided node index is invalid.
    /// @dev The index should be less than `2^height`.
    error InvalidNodeIndex();

    /// @notice Compute the root of a Merkle tree after replacing one of its nodes.
    /// @param sibs The siblings of the node in bottom-up order
    /// @param nodeIndex The index of the node
    /// @param node The new node
    /// @param nodeFromChildren The function that computes nodes from their children
    /// @return The root hash of the new Merkle tree
    /// @dev Level of node is deduced by the length of the siblings array.
    /// @dev Raises an `InvalidNodeIndex` error if an invalid node index is provided.
    function merkleRootAfterReplacement(
        bytes32[] calldata sibs,
        uint256 nodeIndex,
        bytes32 node,
        function(bytes32, bytes32) pure returns (bytes32) nodeFromChildren
    ) internal pure returns (bytes32) {
        uint256 height = sibs.length;
        require((nodeIndex >> height) == 0, InvalidNodeIndex());
        for (uint256 i; i < height; ++i) {
            bool isNodeLeftChild = ((nodeIndex >> i) & 1 == 0);
            bytes32 nodeSibling = sibs[i];
            node = isNodeLeftChild
                ? nodeFromChildren(node, nodeSibling)
                : nodeFromChildren(nodeSibling, node);
        }
        return node;
    }
}
