// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

/// @notice A range of numbers of form `[inclusiveStart, exclusiveEnd)`.
/// @param inclusiveStart The inclusive lower bound
/// @param exclusiveEnd The exclusive upper bound
struct BlockRange {
    uint256 inclusiveStart;
    uint256 exclusiveEnd;
}
