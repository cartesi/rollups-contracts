// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

/// @title Canonical Machine Constants Library
///
/// @notice Defines several constants related to the reference implementation
/// of the RISC-V machine that runs Linux, also known as the "Cartesi Machine".
library CanonicalMachine {
    /// @notice Maximum input size (64 kilobytes).
    uint256 constant INPUT_MAX_SIZE = 1 << 16;

    /// @notice Log2 of maximum number of outputs.
    uint256 constant LOG2_MAX_OUTPUTS = 63;
}
