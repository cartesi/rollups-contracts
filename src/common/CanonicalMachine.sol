// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

/// @title Canonical Machine Constants Library
///
/// @notice Defines several constants related to the reference implementation
/// of the RISC-V machine that runs Linux, also known as the "Cartesi Machine".
library CanonicalMachine {
    /// @notice Maximum input size (64 kilobytes).
    uint64 constant INPUT_MAX_SIZE = 1 << 16;

    /// @notice Log2 of memory size.
    uint8 constant LOG2_MEMORY_SIZE = 64;

    /// @notice Log2 of maximum number of outputs.
    uint8 constant LOG2_MAX_OUTPUTS = 63;

    /// @notice Log2 of data block size.
    uint8 constant LOG2_DATA_BLOCK_SIZE = 5;
}
