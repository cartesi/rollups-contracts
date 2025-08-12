// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

/// @title Tiny bitmap library.
/// @notice Handles 256-bit maps.
/// @dev Bit indices are typed as 8-bit unsigned integers.
library LibTinyBitmap {
    /// @notice The bitmap state struct
    /// @param bitmap The 256-bit map
    /// @dev Allows in-storage read and write operations.
    struct State {
        uint256 bitmap;
    }

    /// @notice Check whether the bit at a given index is set.
    /// @param state The bitmap state
    /// @param index The index of the bit
    /// @return Whether the bit at index is set.
    function isBitSet(State storage state, uint8 index) internal view returns (bool) {
        return (state.bitmap & getBitMask(index)) != 0;
    }

    /// @notice Set the bit at a given index.
    /// @param state The bitmap state
    /// @param index The index of the bit
    function setBitAt(State storage state, uint8 index) internal {
        state.bitmap |= getBitMask(index);
    }

    /// @notice Count the number of set bits in a bitmap.
    /// @param state The bitmap state
    /// @return numberOfSetBits The number of set bits.
    /// @dev Uses Brian Kernighan's method of repeatedly unsetting the rightmost set bit.
    function countSetBits(State storage state)
        internal
        view
        returns (uint256 numberOfSetBits)
    {
        uint256 bitmap = state.bitmap;
        while (bitmap != 0) {
            bitmap &= bitmap - 1;
            ++numberOfSetBits;
        }
    }

    /// @notice Extracts the 256-bit map as a `bytes32` value.
    /// @param state The bitmap state
    /// @return bitmap The 256-bit bitmap
    function toBytes32(State storage state) internal view returns (bytes32 bitmap) {
        return bytes32(state.bitmap);
    }

    /// @notice Get the mask of a bit given its index.
    /// @param index The index of the bit
    /// @return A bitmap with only the bit set
    function getBitMask(uint8 index) internal pure returns (uint256) {
        return 1 << index;
    }
}
