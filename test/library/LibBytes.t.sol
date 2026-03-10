// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Test} from "forge-std-1.9.6/src/Test.sol";

import {LibBytes} from "src/library/LibBytes.sol";

contract LibBytesTest is Test {
    using LibBytes for bytes;

    function testConsumeBytes4(bytes calldata buffer) external pure {
        (bool isBufferValid, bytes4 selector, bytes memory arguments) =
            buffer.consumeBytes4();
        if (isBufferValid) {
            assertGe(
                buffer.length,
                4,
                "Expected buffer.length >= 4 (when isBufferValid = true)"
            );
            assertEq(
                abi.encodePacked(selector, arguments),
                buffer,
                "Expected abi.encodePacked(selector, arguments) = buffer"
            );
            assertEq(selector, bytes4(buffer[:4]), "Expected selector = buffer[:4]");
            assertEq(arguments, buffer[4:], "Expected selector = buffer[:4]");
        } else {
            assertLt(
                buffer.length,
                4,
                "Expected buffer.length < 4 (when isBufferValid = false)"
            );
        }
    }
}
