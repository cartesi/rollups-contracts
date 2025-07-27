// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

/// @notice A range of numbers of form `[start,end)`.
/// @param start The inclusive lower bound
/// @param end The exclusive upper bound
struct BlockRange {
    uint256 start;
    uint256 end;
}
