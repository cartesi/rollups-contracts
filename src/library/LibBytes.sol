// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

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
            for (uint256 i; i < 4; ++i) {
                selector |= (bytes4(buffer[i]) >> (8 * i));
            }
            arguments = new bytes(buffer.length - 4);
            for (uint256 i; i < arguments.length; ++i) {
                arguments[i] = buffer[i + 4];
            }
        }
    }
}
