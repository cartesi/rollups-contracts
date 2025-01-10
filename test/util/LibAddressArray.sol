// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Vm} from "forge-std/Vm.sol";

library LibAddressArray {
    function generate(
        Vm vm,
        uint256 n
    ) internal pure returns (address[] memory) {
        address[] memory array = new address[](n);
        for (uint256 i; i < n; ++i) {
            array[i] = vm.addr(i + 1);
        }
        return array;
    }

    function contains(
        address[] memory array,
        address addr
    ) internal pure returns (bool) {
        for (uint256 i; i < array.length; ++i) {
            if (array[i] == addr) {
                return true;
            }
        }
        return false;
    }
}
