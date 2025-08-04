// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

/// @title 256-bit map library.
/// @notice Handles 256-bit values as bitmaps.
/// @dev Bit indices are typed as 8-bit unsigned integers.
library Lib256Bitmap {
    /// @notice Check whether the bit at a given index is set.
    /// @param bitmap The bitmap
    /// @param index The index of the bit
    /// @return Whether the bit at index is set.
    function isBitSet(bytes32 bitmap, uint8 index) internal pure returns (bool) {
        return (bitmap & getBitMask(index)) != bytes32(0);
    }

    /// @notice Set the bit at a given index.
    /// @param bitmap The bitmap
    /// @param index The index of the bit
    /// @return The new bitmap with the bit at index set.
    function setBitAt(bytes32 bitmap, uint8 index) internal pure returns (bytes32) {
        return bitmap | getBitMask(index);
    }

    /// @notice Count the number of set bits in a bitmap.
    /// @param bitmap The bitmap
    /// @return numberOfSetBits The number of set bits.
    /// @dev Uses Brian Kernighan's method of repeatedly unsetting the rightmost set bit.
    function countSetBits(bytes32 bitmap)
        internal
        pure
        returns (uint256 numberOfSetBits)
    {
        while (bitmap != bytes32(0)) {
            bitmap &= bytes32(uint256(bitmap) - 1);
            ++numberOfSetBits;
        }
    }

    /// @notice Get the mask of a bit given its index.
    /// @param index The index of the bit
    /// @return A bitmap with only the bit set
    function getBitMask(uint8 index) internal pure returns (bytes32) {
        return bytes32(uint256(1)) << index;
    }
}
