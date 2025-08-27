// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {EmulatorConstants} from "step/src/EmulatorConstants.sol";
import {Memory} from "step/src/Memory.sol";

/// @title Canonical Machine Constants Library
///
/// @notice Defines several constants related to the reference implementation
/// of the RISC-V machine that runs Linux, also known as the "Cartesi Machine".
library CanonicalMachine {
    /// @notice Maximum input size (2 megabytes).
    uint256 constant INPUT_MAX_SIZE = 1 << EmulatorConstants.PMA_CMIO_TX_BUFFER_LOG2_SIZE;

    /// @notice Log2 of maximum number of outputs.
    uint64 constant LOG2_MAX_OUTPUTS = 63;

    /// @notice Log2 of memory size.
    uint64 constant LOG2_MEMORY_SIZE = Memory.LOG2_MAX_SIZE;

    /// @notice Log2 of Merkle tree data block size.
    /// @dev Used when computing the the machine memory Merkle root.
    uint64 constant LOG2_DATA_BLOCK_SIZE = EmulatorConstants.TREE_LOG2_WORD_SIZE;

    /// @notice Merkle tree height.
    /// @dev height
    ///      = log_2 #leaves
    ///      = log_2 (memorySize / dataBlockSize)
    ///      = log_2 memorySize - log_2 dataBlockSize
    uint64 constant TREE_HEIGHT = LOG2_MEMORY_SIZE - LOG2_DATA_BLOCK_SIZE;

    /// @notice The start address of the tx buffer.
    /// @dev Used to write outputs and the outputs Merkle root.
    uint64 constant TX_BUFFER_START = EmulatorConstants.PMA_CMIO_TX_BUFFER_START;

    /// @notice The leaf index of the outputs Merkle root (tx buffer start).
    /// @dev Useful for validating the outputs Merkle root from the machine root.
    uint64 constant OUTPUTS_ROOT_LEAF_INDEX = TX_BUFFER_START >> LOG2_DATA_BLOCK_SIZE;
}
