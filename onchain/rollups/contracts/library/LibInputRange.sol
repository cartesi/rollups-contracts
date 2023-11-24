// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {InputRange} from "../common/InputRange.sol";

library LibInputRange {
    /// @notice Check if an input range represents the empty set.
    /// @param r The input range
    /// @return Whether the input range represents the empty set.
    function isEmptySet(InputRange calldata r) internal pure returns (bool) {
        return r.firstInputIndex > r.lastInputIndex;
    }

    /// @notice Check if an input range contains an input.
    /// @param r The input range
    /// @param inputIndex The input index
    /// @return Whether the input range contains the input.
    function contains(
        InputRange calldata r,
        uint256 inputIndex
    ) internal pure returns (bool) {
        return
            r.firstInputIndex <= inputIndex && inputIndex <= r.lastInputIndex;
    }
}
