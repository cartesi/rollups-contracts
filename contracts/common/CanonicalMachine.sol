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

    /// @notice Log of maximum number of inputs per epoch.
    uint256 constant LOG2_MAX_INPUTS_PER_EPOCH = 32;

    /// @notice Log of maximum number of outputs per input.
    uint256 constant LOG2_MAX_OUTPUTS_PER_INPUT = 16;
}
