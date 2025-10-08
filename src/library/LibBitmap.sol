// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

/// @title Library for dealing with `bytes32` as 256-bit maps.
/// @dev Bit indices are typed as 8-bit unsigned integers.
library LibBitmap {
    /// @notice The empty bitmap.
    bytes32 constant EMPTY_BITMAP = bytes32(0);

    /// @notice Create a bitmap with a single bit set.
    /// @param index The index of the set bit
    /// @return A bitmap with only the given bit set
    function singleton(uint8 index) internal pure returns (bytes32) {
        return bytes32(1 << index);
    }

    /// @notice Get the bit at a given index.
    /// @param bitmap The bitmap
    /// @param index The bit index
    /// @return The bit at the given index.
    function getBitAt(bytes32 bitmap, uint8 index) internal pure returns (bool) {
        return (bitmap & singleton(index)) != EMPTY_BITMAP;
    }

    /// @notice Set a bit at a given index.
    /// @param bitmap The bitmap
    /// @param index The bit index
    /// @return The new bitmap with the bit set
    function setBitAt(bytes32 bitmap, uint8 index) internal pure returns (bytes32) {
        return bitmap | singleton(index);
    }

    /// @notice Count the number of set bits in a bitmap.
    /// @param bitmap The bitmap
    /// @return n The number of set bits.
    /// @dev Uses Brian Kernighan's trick of repeatedly
    /// unsetting the rightmost set bit.
    function countSetBits(bytes32 bitmap) internal pure returns (uint256 n) {
        while (bitmap != EMPTY_BITMAP) {
            bitmap &= bytes32(uint256(bitmap) - 1);
            ++n;
        }
    }
}
