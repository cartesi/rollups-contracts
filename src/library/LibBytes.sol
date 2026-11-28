// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

library LibBytes {
    function consumeBytes4(bytes memory buffer)
        internal
        pure
        returns (bool isBufferValid, bytes4 selector, bytes memory arguments)
    {
        if (buffer.length < 4) {
            isBufferValid = false;
        } else {
            isBufferValid = true;
            arguments = new bytes(buffer.length - 4);
            assembly ("memory-safe") {
                selector := and(mload(add(buffer, 0x20)), shl(224, 0xffffffff))
                mcopy(add(arguments, 0x20), add(buffer, 0x24), mload(arguments))
            }
        }
    }
}
