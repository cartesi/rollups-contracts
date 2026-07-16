// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

/// @notice A compressed node represents a value that is repeated
/// (1 + extra) times in a layer of a Merkle tree. This is a very
/// useful intermediary representation for sparse Merkle trees.
/// @param value The node value
/// @param extra The extra times the node is repeated
struct CompressedNode {
    bytes32 value;
    uint256 extra;
}
