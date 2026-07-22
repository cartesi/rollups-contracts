// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {EmulatorConstants} from "cartesi-machine-solidity-step-0.15.0/src/EmulatorConstants.sol";
import {Memory} from "cartesi-machine-solidity-step-0.15.0/src/Memory.sol";

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
    uint8 constant LOG2_DATA_BLOCK_SIZE = Memory.LOG2_LEAF;

    /// @notice Data block mask.
    uint64 constant DATA_BLOCK_MASK = Memory.LEAF_MASK;

    /// @notice Log2 of memory tree height.
    uint8 constant MEMORY_TREE_HEIGHT = LOG2_MEMORY_SIZE - LOG2_DATA_BLOCK_SIZE;

    /// @notice TX buffer start.
    uint64 constant TX_BUFFER_START = EmulatorConstants.AR_CMIO_TX_BUFFER_START;

    /// @notice Internal Y flag address.
    uint64 constant IFLAGS_Y_ADDRESS = EmulatorConstants.IFLAGS_Y_ADDRESS;

    /// @notice HTIF tohost address.
    uint64 constant HTIF_TOHOST_ADDRESS = EmulatorConstants.HTIF_TOHOST_ADDRESS;
}
