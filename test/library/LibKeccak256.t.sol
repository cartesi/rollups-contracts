// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Test} from "forge-std-1.9.6/src/Test.sol";

import {LibKeccak256} from "src/library/LibKeccak256.sol";

/// @title Alternative naive, gas-inefficient implementation of LibKeccak256
library LibNaiveKeccak256 {
    function hashBytes(bytes memory b) internal pure returns (bytes32) {
        return keccak256(b);
    }

    function hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return keccak256(abi.encode(a, b));
    }
}

contract LibKeccak256Test is Test {
    function testHashBytes(bytes memory b) external pure {
        assertEq(LibKeccak256.hashBytes(b), LibNaiveKeccak256.hashBytes(b));
    }

    function testHashPair(bytes32 a, bytes32 b) external pure {
        assertEq(LibKeccak256.hashPair(a, b), LibNaiveKeccak256.hashPair(a, b));
    }
}
