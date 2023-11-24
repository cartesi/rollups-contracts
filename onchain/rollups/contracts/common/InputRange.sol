// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

/// @notice A range of input indices.
/// @param firstInputIndex The index of the first input
/// @param lastInputIndex The index of the last input
struct InputRange {
    uint256 firstInputIndex;
    uint256 lastInputIndex;
}
