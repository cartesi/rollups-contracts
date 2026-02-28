// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

library LibMath {
    /// @notice Get the smallest of two numbers.
    /// @param a The first number
    /// @param b The second number
    /// @return The smallest of the two numbers
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a <= b ? a : b;
    }
}
