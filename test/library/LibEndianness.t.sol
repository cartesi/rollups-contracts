// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {Test} from "forge-std-1.9.6/src/Test.sol";

import {LibEndianness} from "../../src/library/LibEndianness.sol";

/// @title Alternative naive, gas-inefficient implementation of LibEndianness
library LibNaiveEndianness {
    function swapEndianness(bytes32 b) internal pure returns (bytes32 r) {
        for (uint256 i; i < 32; ++i) {
            r |= bytes32(b[i]) >> (8 * (31 - i));
        }
    }
}

contract LibEndiannessTest is Test {
    function testSwapEndianness() external pure {
        assertEq(LibEndianness.swapEndianness(0), 0);
        assertEq(
            LibEndianness.swapEndianness(bytes32(type(uint256).max)),
            bytes32(type(uint256).max)
        );
        assertEq(
            LibEndianness.swapEndianness(
                0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f
            ),
            0x1f1e1d1c1b1a191817161514131211100f0e0d0c0b0a09080706050403020100
        );
        for (uint256 i; i < 32; ++i) {
            // A byte at index i should be moved to index 31 - i
            bytes32 b = bytes32(bytes1(0xff)) >> (8 * i);
            bytes32 r = bytes32(bytes1(0xff)) >> (8 * (31 - i));
            assertEq(LibEndianness.swapEndianness(b), r);
            for (uint256 j; j < i; ++j) {
                bytes32 c = bytes32(bytes1(0x01)) >> (8 * j);
                bytes32 s = bytes32(bytes1(0x01)) >> (8 * (31 - j));
                assertEq(LibEndianness.swapEndianness(b | c), r | s);
            }
        }
    }

    function testSwapEndianness(bytes32 b) external pure {
        bytes32 r = LibEndianness.swapEndianness(b);
        assertEq(r, LibNaiveEndianness.swapEndianness(b));

        // Swapping the endianness twice should yield the original value
        assertEq(LibEndianness.swapEndianness(r), b);
    }
}
