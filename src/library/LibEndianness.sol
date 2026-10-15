// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

library LibEndianness {
    uint256 constant MASK_8 =
        0x00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF;
    uint256 constant MASK_16 =
        0x0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF;
    uint256 constant MASK_32 =
        0x00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF;
    uint256 constant MASK_64 =
        0x0000000000000000FFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF;

    /// @notice Swap the endianness of a 32-byte value
    /// @param b The 32-byte value
    function swapEndianness(bytes32 b) internal pure returns (bytes32) {
        uint256 v = uint256(b);

        // swap adjacent bytes
        v = ((v >> 8) & MASK_8) | ((v & MASK_8) << 8);
        // swap 2-byte pairs
        v = ((v >> 16) & MASK_16) | ((v & MASK_16) << 16);
        // swap 4-byte pairs
        v = ((v >> 32) & MASK_32) | ((v & MASK_32) << 32);
        // swap 8-byte pairs
        v = ((v >> 64) & MASK_64) | ((v & MASK_64) << 64);
        // swap 16-byte halves
        v = (v >> 128) | (v << 128);

        return bytes32(v);
    }
}
