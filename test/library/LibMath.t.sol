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

    function ceilLog2(uint256 x) internal pure returns (uint256) {
        for (uint256 i; i < 256; ++i) {
            if (x <= (1 << i)) {
                return i;
            }
        }
        return 256;
    }

    function floorLog2(uint256 x) internal pure returns (uint256) {
        require(x > 0, "floorLog2(0) is undefined");
        for (uint256 i; i < 256; ++i) {
            if ((x >> i) == 1) {
                return i;
            }
        }
        revert("unexpected code path reached");
    }
}

library ExternalLibMath {
    function floorLog2(uint256 x) external pure returns (uint256) {
        return LibMath.floorLog2(x);
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

    function testCeilLog2() external pure {
        assertEq(LibMath.ceilLog2(0), 0);
        assertEq(LibMath.ceilLog2(type(uint256).max), 256);
        for (uint256 i; i < 256; ++i) {
            assertEq(LibMath.ceilLog2(1 << i), i);
            for (uint256 j; j < i; ++j) {
                assertEq(LibMath.ceilLog2((1 << i) | (1 << j)), i + 1);
            }
        }
    }

    function testCeilLog2(uint256 x) external pure {
        uint256 y = LibMath.ceilLog2(x);
        assertEq(y, LibNaiveMath.ceilLog2(x));

        // Check that x <= 2^y
        if (y < 256) {
            // If y < 256, then we can
            // represent 2^y in an EVM word
            assertLe(x, 1 << y);
        } else {
            // For any uint256 value x,
            // it is true that x < 2^256
            assertEq(y, 256);
        }

        // Check that y is the smallest
        // number possible that satisfies
        // x <= 2^y. That is, check that
        // it doesn't hold for y-1.
        if (y >= 1) {
            assertGe(x, 1 << (y - 1));
        }
    }

    function testFloorLog2() external pure {
        assertEq(LibMath.floorLog2(1), 0);
        assertEq(LibMath.floorLog2(type(uint256).max), 255);
        for (uint256 i; i < 256; ++i) {
            assertEq(LibMath.floorLog2(1 << i), i);
            for (uint256 j; j < i; ++j) {
                assertEq(LibMath.floorLog2((1 << i) | (1 << j)), i);
                assertEq(LibMath.floorLog2((1 << i) - (1 << j)), i - 1);
            }
        }
    }

    function testFloorLog2(uint256 x) external pure {
        vm.assume(x > 0);
        uint256 y = LibMath.floorLog2(x);
        assertEq(y, LibNaiveMath.floorLog2(x));

        // For any uint256 value x,
        // it is not true that x >= 2^256
        assertLt(y, 256);

        // Check that x >= 2^y
        // Because y < 256, we can
        // represent 2^y in an EVM word.
        assertGe(x, 1 << y);

        // Check that y is the biggest
        // number possible that satisfies
        // x >= 2^y. That is, check that
        // it doesn't hold for y+1.
        // We don't need to check
        // For y = 255, we don't need
        // to check, because for any
        // uint256 value x, it is always
        // true that x < 2^256.
        if ((y + 1) < 256) {
            assertLt(x, 1 << (y + 1));
        }
    }

    function testFloorLog2OfZero() external {
        vm.expectRevert(LibMath.FloorLog2OfZeroIsUndefined.selector);
        ExternalLibMath.floorLog2(0);
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
