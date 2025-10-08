// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Vm} from "forge-std-1.10.0/src/Vm.sol";

library LibAddressArray {
    function contains(address[] memory array, address elem)
        internal
        pure
        returns (bool)
    {
        for (uint256 i; i < array.length; ++i) {
            if (array[i] == elem) {
                return true;
            }
        }
        return false;
    }

    function eq(address[] memory array1, address[] memory array2)
        internal
        pure
        returns (bool)
    {
        return keccak256(abi.encode(array1)) == keccak256(abi.encode(array2));
    }

    function neq(address[] memory array1, address[] memory array2)
        internal
        pure
        returns (bool)
    {
        return !eq(array1, array2);
    }

    function randomAddresses(Vm vm, uint256 n)
        internal
        view
        returns (address[] memory array)
    {
        array = new address[](n);
        for (uint256 i; i < n; ++i) {
            array[i] = vm.randomAddress();
        }
    }

    function addrs(Vm vm, uint256 n) internal pure returns (address[] memory array) {
        array = new address[](n);
        for (uint256 i; i < n; ++i) {
            array[i] = vm.addr(i + 1);
        }
    }
}
