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

    function randomUniqueUint256Array(Vm vm, uint256 n)
        internal
        returns (uint256[] memory array)
    {
        array = new uint256[](n);
        for (uint256 i; i < array.length; ++i) {
            uint256 elem;
            while (true) {
                elem = vm.randomUint();
                if (!containsBefore(array, elem, i)) {
                    break;
                }
            }
            array[i] = elem;
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
        return containsBefore(array, elem, array.length);
    }

    function containsBefore(uint256[] memory array, uint256 elem, uint256 n)
        internal
        pure
        returns (bool)
    {
        require(n <= array.length, "cannot check past array length");
        for (uint256 i; i < n; ++i) {
            if (array[i] == elem) {
                return true;
            }
        }
        return false;
    }

    function sub(uint256[] memory a, uint256[] memory b)
        internal
        pure
        returns (uint256[] memory c)
    {
        require(a.length == b.length, "vector subtraction terms have inequal lengths");
        c = new uint256[](a.length);
        for (uint256 i; i < a.length; ++i) {
            c[i] = a[i] - b[i];
        }
    }

    function add(uint256[] memory a, uint256[] memory b)
        internal
        pure
        returns (uint256[] memory c)
    {
        require(a.length == b.length, "vector addition terms have inequal lengths");
        c = new uint256[](a.length);
        for (uint256 i; i < a.length; ++i) {
            c[i] = a[i] + b[i];
        }
    }

    function max(uint256[] memory array)
        external
        pure
        returns (bool isEmpty, uint256 maxElem)
    {
        (isEmpty, maxElem) = maxBefore(array, array.length);
    }

    error InvalidSubArrayLength(uint256 subArrayLength, uint256 arrayLength);

    function maxBefore(uint256[] memory array, uint256 subArrayLength)
        public
        pure
        returns (bool isEmpty, uint256 maxElem)
    {
        if (subArrayLength == 0) {
            isEmpty = true;
            maxElem = 0;
        } else {
            require(
                subArrayLength <= array.length,
                InvalidSubArrayLength(subArrayLength, array.length)
            );
            isEmpty = false;
            maxElem = array[0];
            for (uint256 i = 1; i < subArrayLength; ++i) {
                if (array[i] > maxElem) {
                    maxElem = array[i];
                }
            }
        }
    }
}
