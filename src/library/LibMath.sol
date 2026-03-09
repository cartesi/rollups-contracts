// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.0;

/// @author Felipe Argento
library LibMath {
    /// @notice Count trailing zeros.
    /// @param x The number you want the ctz of
    /// @dev This is a binary search implementation.
    function ctz(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 256;
        else return 256 - clz(~x & (x - 1));
    }

    /// @notice Count leading zeros.
    /// @param x The number you want the clz of
    /// @dev This a binary search implementation.
    function clz(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 256;

        uint256 n = 0;
        if (x & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00000000000000000000000000000000 == 0) {
            n = n + 128;
            x = x << 128;
        }
        if (x & 0xFFFFFFFFFFFFFFFF000000000000000000000000000000000000000000000000 == 0) {
            n = n + 64;
            x = x << 64;
        }
        if (x & 0xFFFFFFFF00000000000000000000000000000000000000000000000000000000 == 0) {
            n = n + 32;
            x = x << 32;
        }
        if (x & 0xFFFF000000000000000000000000000000000000000000000000000000000000 == 0) {
            n = n + 16;
            x = x << 16;
        }
        if (x & 0xFF00000000000000000000000000000000000000000000000000000000000000 == 0) {
            n = n + 8;
            x = x << 8;
        }
        if (x & 0xF000000000000000000000000000000000000000000000000000000000000000 == 0) {
            n = n + 4;
            x = x << 4;
        }
        if (x & 0xC000000000000000000000000000000000000000000000000000000000000000 == 0) {
            n = n + 2;
            x = x << 2;
        }
        if (x & 0x8000000000000000000000000000000000000000000000000000000000000000 == 0) {
            n = n + 1;
        }

        return n;
    }

    /// @notice The smallest y for which x <= 2^y.
    /// @param x The number you want the ceilLog2 of
    /// @dev This is a binary search implementation.
    function ceilLog2(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        else return 256 - clz(x - 1);
    }

    /// @notice Tried to compute floorLog2(0), which is undefined.
    error FloorLog2OfZeroIsUndefined();

    /// @notice The biggest y for which x >= 2^y.
    /// @param x The number you want the floorLog2 of
    /// @dev This is a binary search implementation.
    /// @dev This function reverts if x = 0 is provided.
    function floorLog2(uint256 x) internal pure returns (uint256) {
        if (x == 0) revert FloorLog2OfZeroIsUndefined();
        else return 255 - clz(x);
    }

    /// @notice The largest of two numbers.
    function max(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x > y) ? x : y;
    }

    /// @notice The smallest of two numbers.
    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x < y) ? x : y;
    }
}
