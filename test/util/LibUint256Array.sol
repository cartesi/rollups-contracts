// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Vm} from "forge-std-1.9.6/src/Vm.sol";

library LibUint256Array {
    function shuffleInPlace(Vm vm, uint256[] memory array) internal {
        // Nothing to be done.
        if (array.length == 0) {
            return;
        }

        // Fisher-Yates shuffle
        for (uint256 i = array.length - 1; i > 0; --i) {
            uint256 j = vm.randomUint(0, i);
            (array[i], array[j]) = (array[j], array[i]);
        }
    }

    function sequence(uint256 start, uint256 n)
        internal
        pure
        returns (uint256[] memory array)
    {
        require(n == 0 || (n - 1) <= type(uint256).max - start, "sequence would overflow");
        array = new uint256[](n);
        for (uint256 index; index < array.length; ++index) {
            array[index] = start + index;
        }
    }

    function split(uint256[] memory array, uint256 firstLength)
        internal
        pure
        returns (uint256[] memory first, uint256[] memory second)
    {
        require(firstLength <= array.length, "Invalid index");
        first = new uint256[](firstLength);
        for (uint256 j; j < first.length; ++j) {
            first[j] = array[j];
        }
        second = new uint256[](array.length - firstLength);
        for (uint256 j; j < second.length; ++j) {
            second[j] = array[firstLength + j];
        }
    }

    function contains(uint256[] memory array, uint256 elem) internal pure returns (bool) {
        for (uint256 i; i < array.length; ++i) {
            if (array[i] == elem) {
                return true;
            }
        }
        return false;
    }
}
