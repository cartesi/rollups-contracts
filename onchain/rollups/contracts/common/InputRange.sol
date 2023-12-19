// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

/// @notice A range of input indices.
/// @param firstIndex The index of the first input
/// @param lastIndex The index of the last input
struct InputRange {
    uint256 firstIndex;
    uint256 lastIndex;
}
