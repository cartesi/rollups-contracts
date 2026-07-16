// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

/// @notice A sparse node represents a value that is repeated
/// (1 + extra) times starting from some index. This is a very
/// useful dev-facing representation for sparse Merkle trees.
/// @param index The node index
/// @param value The node value
/// @param extra The extra times the node is repeated
struct SparseNode {
    uint256 index;
    bytes32 value;
    uint256 extra;
}
