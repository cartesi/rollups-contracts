// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Test} from "forge-std-1.9.6/src/Test.sol";

import {LibKeccak256} from "src/library/LibKeccak256.sol";
import {LibMath} from "src/library/LibMath.sol";

/// @title Alternative naive, gas-inefficient implementation of LibKeccak256
library LibNaiveKeccak256 {
    function hashBytes(bytes memory b) internal pure returns (bytes32) {
        return keccak256(b);
    }

    function hashBlock(bytes memory data, uint256 dataBlockIndex, uint256 dataBlockSize)
        internal
        pure
        returns (bytes32 result)
    {
        bytes memory dataBlock = new bytes(dataBlockSize);
        uint256 offset = dataBlockIndex * dataBlockSize;
        for (uint256 i; i < dataBlockSize; ++i) {
            if (offset + i < data.length) {
                dataBlock[i] = data[offset + i];
            }
        }
        return keccak256(dataBlock);
    }

    function hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return keccak256(abi.encode(a, b));
    }
}

contract LibKeccak256Test is Test {
    using LibMath for uint256;

    function testHashBytes(bytes memory b) external pure {
        assertEq(LibKeccak256.hashBytes(b), LibNaiveKeccak256.hashBytes(b));
    }

    function testHashBlock(
        bytes memory data,
        uint256 dataBlockIndex,
        uint256 dataBlockSize
    ) external pure {
        // We need to bound the data block size because, otherwise,
        // allocating a data block too large would lead to an out-of-gas error.
        dataBlockSize = bound(dataBlockSize, 0, 1 << 12);

        // We also need to bound the data block index because, otherwise,
        // calculating the data offset would lead to an arithmetic error.
        uint256 maxDataBlockIndex = type(uint256).max / dataBlockSize.max(1) - 1;
        dataBlockIndex = bound(dataBlockIndex, 0, maxDataBlockIndex);

        // Finally, we assert that our naive implementation matches the main one
        // for every possible combination of inputs.
        assertEq(
            LibKeccak256.hashBlock(data, dataBlockIndex, dataBlockSize),
            LibNaiveKeccak256.hashBlock(data, dataBlockIndex, dataBlockSize)
        );
    }

    function testHashPair(bytes32 a, bytes32 b) external pure {
        assertEq(LibKeccak256.hashPair(a, b), LibNaiveKeccak256.hashPair(a, b));
    }
}
