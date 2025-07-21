// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

/// @title Canonical Machine Constants Library
///
/// @notice Defines several constants related to the reference implementation
/// of the RISC-V machine that runs Linux, also known as the "Cartesi Machine".
library CanonicalMachine {
    /// @notice Maximum input size (2 megabytes).
    uint256 constant INPUT_MAX_SIZE = 1 << 21;

    /// @notice Log2 of maximum number of outputs.
    uint256 constant LOG2_MAX_OUTPUTS = 63;

    /// @notice Log2 of memory size.
    uint256 constant LOG2_MEMORY_SIZE = 64;

    /// @notice Log2 of Merkle tree data block size.
    /// @dev Used when computing the the machine memory Merkle root.
    uint256 constant LOG2_MERKLE_TREE_DATA_BLOCK_SIZE = 5;

    /// @notice Merkle tree height.
    /// @dev height
    ///      = log_2 #leaves
    ///      = log_2 (memorySize / dataBlockSize)
    ///      = log_2 memorySize - log_2 dataBlockSize
    uint256 constant MERKLE_TREE_HEIGHT =
        LOG2_MEMORY_SIZE - LOG2_MERKLE_TREE_DATA_BLOCK_SIZE;
}
