// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Test} from "forge-std-1.9.6/src/Test.sol";
import {Vm} from "forge-std-1.9.6/src/Vm.sol";

import {LibAddressArray} from "./LibAddressArray.sol";

library ExternalLibAddressArray {
    function randomAddressIn(Vm vm, address[] memory array)
        external
        returns (address addr)
    {
        addr = LibAddressArray.randomAddressIn(vm, array);
    }
}

contract LibAddressArrayTest is Test {
    using LibAddressArray for address[];
    using LibAddressArray for Vm;

    function testRandomAddressIn(address[] memory array) external {
        vm.assume(array.length > 0);
        assertTrue(array.contains(vm.randomAddressIn(array)));
    }

    function testRandomAddressInEmptyArray() external {
        address[] memory emptyArray = new address[](0);
        vm.expectRevert("Cannot sample random element from empty array");
        ExternalLibAddressArray.randomAddressIn(vm, emptyArray);
    }

    function testRandomAddressInSingleton(address elem) external {
        address[] memory singleton = new address[](1);
        singleton[0] = elem;
        assertEq(vm.randomAddressIn(singleton), elem);
    }

    function testRandomAddressNotIn(address[] memory array) external {
        assertFalse(array.contains(vm.randomAddressNotIn(array)));
    }

    function testContains(address[] memory array) external {
        for (uint256 i; i < array.length; ++i) {
            assertTrue(array.contains(array[i]));
        }
        address notElement;
        while (true) {
            bool isElement;
            notElement = vm.randomAddress();
            for (uint256 i; i < array.length; ++i) {
                if (notElement == array[i]) {
                    isElement = true;
                    break;
                }
            }
            if (!isElement) {
                break;
            }
        }
        assertFalse(array.contains(notElement));
    }

    function testContains(address elem) external pure {
        address[] memory emptyArray = new address[](0);
        assertFalse(emptyArray.contains(elem));

        address[] memory singleton = new address[](1);
        singleton[0] = elem;
        assertTrue(singleton.contains(elem));
    }

    function testContains(address a, address b) external pure {
        vm.assume(a != b);

        address[] memory emptyArray = new address[](0);
        assertFalse(emptyArray.contains(a));
        assertFalse(emptyArray.contains(b));

        address[] memory singletonA = new address[](1);
        singletonA[0] = a;
        assertTrue(singletonA.contains(a));
        assertFalse(singletonA.contains(b));

        address[] memory singletonB = new address[](1);
        singletonB[0] = b;
        assertFalse(singletonB.contains(a));
        assertTrue(singletonB.contains(b));

        address[] memory ab = new address[](2);
        ab[0] = a;
        ab[1] = b;
        assertTrue(ab.contains(a));
        assertTrue(ab.contains(b));

        address[] memory ba = new address[](2);
        ba[0] = b;
        ba[1] = a;
        assertTrue(ba.contains(a));
        assertTrue(ba.contains(b));
    }
}
