// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Test} from "forge-std-1.10.0/src/Test.sol";

import {LibBitmap} from "src/library/LibBitmap.sol";

/// @title Alternative naive, gas-inefficient implementation of LibBitmap
library LibNaiveBitmap {
    /// @notice Converts a `bytes32` value into an array of 256 boolean values.
    /// @param b32Value The 32-byte value
    /// @return boolArray The boolean array
    function toBoolArray(bytes32 b32Value)
        internal
        pure
        returns (bool[256] memory boolArray)
    {
        for (uint256 i; i < boolArray.length; ++i) {
            boolArray[i] = ((uint256(b32Value) >> i) & 1 == 1);
        }
    }

    /// @notice Converts an array of 256 boolean values into a `bytes32` value.
    /// @param boolArray The boolean array
    /// @return b32Value The 32-byte value
    function fromBoolArray(bool[256] memory boolArray)
        internal
        pure
        returns (bytes32 b32Value)
    {
        for (uint256 i; i < boolArray.length; ++i) {
            b32Value |= bytes32((boolArray[i] ? uint256(1) : 0) << i);
        }
    }

    /// @notice Create a bitmap with a single bit set.
    /// @param index The index of the set bit
    /// @return A bitmap with only the given bit set
    function singleton(uint8 index) internal pure returns (bytes32) {
        bool[256] memory boolArray;
        boolArray[index] = true;
        return fromBoolArray(boolArray);
    }

    /// @notice Get the bit at a given index.
    /// @param bitmap The bitmap
    /// @param index The bit index
    /// @return The bit at the given index.
    function getBitAt(bytes32 bitmap, uint8 index) internal pure returns (bool) {
        return toBoolArray(bitmap)[index];
    }

    /// @notice Set a bit at a given index.
    /// @param bitmap The bitmap
    /// @param index The bit index
    /// @return The new bitmap with the bit set
    function setBitAt(bytes32 bitmap, uint8 index) internal pure returns (bytes32) {
        bool[256] memory boolArray = toBoolArray(bitmap);
        boolArray[index] = true;
        return fromBoolArray(boolArray);
    }

    /// @notice Count the number of set bits in a bitmap.
    /// @param bitmap The bitmap
    /// @return n The number of set bits.
    function countSetBits(bytes32 bitmap) internal pure returns (uint256 n) {
        bool[256] memory boolArray = toBoolArray(bitmap);
        for (uint256 i; i < boolArray.length; ++i) {
            if (boolArray[i]) {
                ++n;
            }
        }
    }
}

contract LibBitmapTest is Test {
    using LibNaiveBitmap for bool[256];
    using LibNaiveBitmap for bytes32;

    function testBoolArrayRoundtrip(bytes32 b32Value) external pure {
        assertEq(
            b32Value.toBoolArray().fromBoolArray(),
            b32Value,
            "roundtrip b32 -> boolArray -> b32 failed"
        );
    }

    function testBoolArrayRoundtrip(bool[256] memory boolArray) external pure {
        assertEq(
            abi.encodePacked(boolArray.fromBoolArray().toBoolArray()),
            abi.encodePacked(boolArray),
            "roundtrip boolArray -> b32 -> boolArray failed"
        );
    }

    function testEmptyBitmap() external pure {
        bool[256] memory boolArray;
        assertEq(
            boolArray.fromBoolArray(),
            LibBitmap.EMPTY_BITMAP,
            "empty bitmap is not equivalent to a array full of false values"
        );
    }

    function testSingleton(uint8 index) external pure {
        assertEq(
            LibBitmap.singleton(index),
            LibNaiveBitmap.singleton(index),
            "naive implementation of singleton diverges from real one"
        );
    }

    function testGetBitAt(bytes32 bitmap, uint8 index) external pure {
        assertEq(
            LibBitmap.getBitAt(bitmap, index),
            LibNaiveBitmap.getBitAt(bitmap, index),
            "naive implementation of getBitAt diverges from real one"
        );
    }

    function testSetBitAt(bytes32 bitmap, uint8 index) external pure {
        assertEq(
            LibBitmap.setBitAt(bitmap, index),
            LibNaiveBitmap.setBitAt(bitmap, index),
            "naive implementation of setBitAt diverges from real one"
        );
    }

    function testCountSetBits(bytes32 bitmap) external pure {
        assertEq(
            LibBitmap.countSetBits(bitmap),
            LibNaiveBitmap.countSetBits(bitmap),
            "naive implementation of countSetBits diverges from real one"
        );
    }

    function testGetBitOfEmptyBitmap(uint8 index) external pure {
        assertFalse(
            LibBitmap.getBitAt(LibBitmap.EMPTY_BITMAP, index),
            "no bit in the empty bitmap should be set"
        );
    }

    function testCountSetBitsOfEmptyBitmap() external pure {
        assertEq(
            LibBitmap.countSetBits(LibBitmap.EMPTY_BITMAP),
            0,
            "empty bitmap should have zero set bits"
        );
    }

    function testGetBitAfterBitSet(bytes32 bitmap, uint8 index) external pure {
        bytes32 newBitmap = LibBitmap.setBitAt(bitmap, index);
        assertTrue(LibBitmap.getBitAt(newBitmap, index), "setting a bit makes a bit set");
        if (LibBitmap.getBitAt(bitmap, index)) {
            assertEq(bitmap, newBitmap, "setting a set bit does not change the bitmap");
        }
    }

    function testSetBitIdempotent(bytes32 bitmap, uint8 index) external pure {
        bitmap = LibBitmap.setBitAt(bitmap, index);
        assertEq(
            bitmap,
            LibBitmap.setBitAt(bitmap, index),
            "the setBitAt funtion is idempotent"
        );
    }

    function testCountSetBitsAfterBitSet(bytes32 bitmap, uint8 index) external pure {
        uint256 setBitCountBefore = LibBitmap.countSetBits(bitmap);
        bytes32 newBitmap = LibBitmap.setBitAt(bitmap, index);
        uint256 setBitCountAfter = LibBitmap.countSetBits(newBitmap);
        if (LibBitmap.getBitAt(bitmap, index)) {
            assertEq(
                setBitCountAfter,
                setBitCountBefore,
                "setting a bit that was already set doesn't change the set bit count"
            );
        } else {
            assertEq(
                setBitCountAfter,
                setBitCountBefore + 1,
                "setting an unset bit increases the set bit count by 1"
            );
        }
    }

    function testCountSetBitsBounded(bytes32 bitmap) external pure {
        assertLe(LibBitmap.countSetBits(bitmap), 256, "bitmaps have at most 256 bits set");
    }

    function testCountSetBitsOfSingleton(uint8 index) external pure {
        assertEq(
            LibBitmap.countSetBits(LibBitmap.singleton(index)),
            1,
            "singleton bitmap has only 1 bit set"
        );
    }

    function testGetBitOfSingleton(uint8 index) external pure {
        assertTrue(LibBitmap.getBitAt(LibBitmap.singleton(index), index));
    }

    function testGetUnsetBitOfSingleton(uint8 index, uint8 otherIndex) external pure {
        vm.assume(index != otherIndex);
        assertFalse(LibBitmap.getBitAt(LibBitmap.singleton(index), otherIndex));
    }

    function testCountSetBitsAgainstGetBitAt(bytes32 bitmap) external pure {
        uint256 n;
        for (uint256 i; i < 256; ++i) {
            if (LibBitmap.getBitAt(bitmap, uint8(i))) {
                ++n;
            }
        }
        assertEq(n, LibBitmap.countSetBits(bitmap));
    }
}
