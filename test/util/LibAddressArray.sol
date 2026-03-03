// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Vm} from "forge-std-1.9.6/src/Vm.sol";

library LibAddressArray {
    function randomAddressIn(Vm vm, address[] memory array)
        internal
        returns (address addr)
    {
        require(array.length > 0, "Cannot sample random element from empty array");
        addr = array[vm.randomUint(0, array.length - 1)];
    }

    function randomAddressNotIn(Vm vm, address[] memory array)
        internal
        returns (address addr)
    {
        while (true) {
            addr = vm.randomAddress();
            if (!contains(array, addr)) {
                break;
            }
        }
    }

    function contains(address[] memory array, address elem) internal pure returns (bool) {
        for (uint256 i; i < array.length; ++i) {
            if (array[i] == elem) {
                return true;
            }
        }
        return false;
    }

    function repeat(address addr, uint256 n)
        internal
        pure
        returns (address[] memory array)
    {
        array = new address[](n);
        for (uint256 i; i < array.length; ++i) {
            array[i] = addr;
        }
    }
}
