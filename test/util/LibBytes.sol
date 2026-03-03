// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

library LibBytes {
    error BufferTooSmall(bytes buffer, uint256 minSize);

    function consumeBytes4(bytes calldata buffer)
        external
        pure
        onlyBufferLengthGe(buffer, 4)
        returns (bytes4, bytes memory)
    {
        return (bytes4(buffer[:4]), buffer[4:]);
    }

    function consumeAddress(bytes calldata buffer)
        external
        pure
        onlyBufferLengthGe(buffer, 20)
        returns (address, bytes memory)
    {
        return (address(uint160(bytes20(buffer[:20]))), buffer[20:]);
    }

    function consumeUint256(bytes calldata buffer)
        external
        pure
        onlyBufferLengthGe(buffer, 32)
        returns (uint256, bytes memory)
    {
        return (uint256(bytes32(buffer[:32])), buffer[32:]);
    }

    modifier onlyBufferLengthGe(bytes calldata buffer, uint256 minSize) {
        checkBufferLengthAgainstMinSize(buffer, minSize);
        _;
    }

    function checkBufferLengthAgainstMinSize(bytes calldata buffer, uint256 minSize)
        internal
        pure
    {
        require(buffer.length >= minSize, BufferTooSmall(buffer, minSize));
    }
}
