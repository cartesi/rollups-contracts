// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Test} from "forge-std-1.9.6/src/Test.sol";

import {LibMath} from "src/library/LibMath.sol";

/// @title Alternative naive, gas-inefficient implementation of LibMath
library LibNaiveMath {
    function ctz(uint256 x) internal pure returns (uint256) {
        uint256 n = 256;
        while (x != 0) {
            --n;
            x <<= 1;
        }
        return n;
    }

    function clz(uint256 x) internal pure returns (uint256) {
        uint256 n = 256;
        while (x != 0) {
            --n;
            x >>= 1;
        }
        return n;
    }

    function log2clp(uint256 x) internal pure returns (uint256) {
        for (uint256 i; i < 256; ++i) {
            if (x <= (1 << i)) {
                return i;
            }
        }
        return 256;
    }
}

contract LibMathTest is Test {
    function testCtz() external pure {
        assertEq(LibMath.ctz(0), 256);
        assertEq(LibMath.ctz(type(uint256).max), 0);
        for (uint256 i; i < 256; ++i) {
            assertEq(LibMath.ctz(1 << i), i);
            for (uint256 j = i + 1; j < 256; ++j) {
                assertEq(LibMath.ctz((1 << i) | (1 << j)), i);
            }
        }
    }

    function testCtz(uint256 x) external pure {
        assertEq(LibMath.ctz(x), LibNaiveMath.ctz(x));
    }

    function testClz() external pure {
        assertEq(LibMath.clz(0), 256);
        assertEq(LibMath.clz(type(uint256).max), 0);
        for (uint256 i; i < 256; ++i) {
            assertEq(LibMath.clz(1 << i), 255 - i);
            for (uint256 j; j < i; ++j) {
                assertEq(LibMath.clz((1 << i) | (1 << j)), 255 - i);
            }
        }
    }

    function testClz(uint256 x) external pure {
        assertEq(LibMath.clz(x), LibNaiveMath.clz(x));
    }

    function testLog2Clp() external pure {
        assertEq(LibMath.log2clp(0), 0);
        assertEq(LibMath.log2clp(type(uint256).max), 256);
        for (uint256 i; i < 256; ++i) {
            assertEq(LibMath.log2clp(1 << i), i);
            for (uint256 j; j < i; ++j) {
                assertEq(LibMath.log2clp((1 << i) | (1 << j)), i + 1);
            }
        }
    }

    function testLog2Clp(uint256 x) external pure {
        assertEq(LibMath.log2clp(x), LibNaiveMath.log2clp(x));
    }

    function testMin(uint256 x) external pure {
        assertEq(LibMath.min(x, x), x);
        assertEq(LibMath.min(x, 0), 0);
        assertEq(LibMath.min(x, type(uint256).max), x);
    }

    function testMin(uint256 x, uint256 y) external pure {
        uint256 min = LibMath.min(x, y);
        assertLe(min, x);
        assertLe(min, y);
        assertTrue(min == x || min == y);
        assertEq(min, LibMath.min(y, x));
    }

    function testMax(uint256 x) external pure {
        assertEq(LibMath.max(x, x), x);
        assertEq(LibMath.max(x, 0), x);
        assertEq(LibMath.max(x, type(uint256).max), type(uint256).max);
    }

    function testMax(uint256 x, uint256 y) external pure {
        uint256 max = LibMath.max(x, y);
        assertGe(max, x);
        assertGe(max, y);
        assertTrue(max == x || max == y);
        assertEq(max, LibMath.max(y, x));
    }
}
