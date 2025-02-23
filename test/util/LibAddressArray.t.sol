// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";

import {LibAddressArray} from "./LibAddressArray.sol";

contract LibAddressArrayTest is Test {
    using LibAddressArray for address[];

    function testContains(address[] memory array, bytes32 salt) external pure {
        for (uint256 i; i < array.length; ++i) {
            assertTrue(array.contains(array[i]));
        }
        // By the properties of keccak256, this should yield a random address
        // that is not contained in the array
        address elem = address(bytes20(keccak256(abi.encode(array, salt))));
        assertFalse(array.contains(elem));
    }
}
