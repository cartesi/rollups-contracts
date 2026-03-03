// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Test} from "forge-std-1.9.6/src/Test.sol";
import {Vm} from "forge-std-1.9.6/src/Vm.sol";

import {LibMath} from "./LibMath.sol";
import {LibUint256Array} from "./LibUint256Array.sol";

contract LibUint256ArrayTest is Test {
    using LibUint256Array for Vm;

    mapping(uint256 => uint256) _histogram;
    uint256[] _uniqueElements;

    function testShuffleInPlace(uint256[] memory array) external {
        uint256 lengthBefore = array.length;

        for (uint256 i; i < array.length; ++i) {
            uint256 element = array[i];
            if (_histogram[element] == 0) {
                _uniqueElements.push(element);
            }
            ++_histogram[element];
        }

        vm.shuffleInPlace(array);

        assertEq(array.length, lengthBefore, "Length should be the same");

        for (uint256 i; i < _uniqueElements.length; ++i) {
            uint256 element = _uniqueElements[i];
            uint256 count;
            for (uint256 j; j < array.length; ++j) {
                if (array[j] == element) {
                    ++count;
                }
            }
            assertEq(count, _histogram[element]);
        }
    }

    function testSequence(uint256 start) external {
        uint256 maxN = LibMath.min(200, type(uint256).max - start);
        uint256 n = vm.randomUint(0, maxN);
        uint256[] memory array = LibUint256Array.sequence(start, n);
        assertEq(array.length, n);
        for (uint256 i; i < n; ++i) {
            assertEq(array[i], start + i);
        }
    }

    function testSplit(uint256[] memory array) external {
        uint256 firstLength = vm.randomUint(0, array.length);
        (uint256[] memory first, uint256[] memory second) =
            LibUint256Array.split(array, firstLength);
        assertEq(first.length, firstLength);
        assertEq(first.length + second.length, array.length);
        for (uint256 i; i < first.length; ++i) {
            assertEq(first[i], array[i]);
        }
        for (uint256 i; i < second.length; ++i) {
            assertEq(second[i], array[i + firstLength]);
        }
    }

    function testContains(uint256[] memory array) external {
        for (uint256 i; i < array.length; ++i) {
            uint256 elem = array[i];
            assertTrue(LibUint256Array.contains(array, elem));
        }
        uint256 notElem;
        while (true) {
            bool isElem = false;
            notElem = vm.randomUint();
            for (uint256 i; i < array.length; ++i) {
                if (notElem == array[i]) {
                    isElem = true;
                    break;
                }
            }
            if (!isElem) {
                break;
            }
        }
        assertFalse(LibUint256Array.contains(array, notElem));
    }

    function testContainsBefore(uint256[] memory array) external {
        for (uint256 i; i < array.length; ++i) {
            uint256 elem = array[i];
            uint256 j = vm.randomUint(i + 1, array.length);
            assertTrue(
                LibUint256Array.containsBefore(array, elem, j),
                "element in array should be contained before an index greater its own"
            );
        }
        {
            uint256 notElem;
            uint256 i = vm.randomUint(0, array.length);
            while (true) {
                bool isElem = false;
                notElem = vm.randomUint();
                for (uint256 j; j < i; ++j) {
                    if (notElem == array[j]) {
                        isElem = true;
                        break;
                    }
                }
                if (!isElem) {
                    break;
                }
            }
            assertFalse(
                LibUint256Array.containsBefore(array, notElem, i),
                "element not in subarray should not be contained before any of its indices"
            );
        }
    }

    function testRandomUniqueUint256Array(uint8 n) external {
        uint256[] memory array = vm.randomUniqueUint256Array(n);
        assertEq(array.length, n);
        for (uint256 i; i < array.length; ++i) {
            uint256 elem = array[i];
            uint256 count = ++_histogram[elem];
            assertEq(count, 1, "array element not unique");
        }
    }

    function testAddAndSub(uint8 n) external {
        uint256[] memory a = new uint256[](n);
        uint256[] memory b = new uint256[](n);
        uint256[] memory c = new uint256[](n);
        for (uint256 i; i < a.length; ++i) {
            c[i] = vm.randomUint();
            a[i] = vm.randomUint(0, c[i]);
            b[i] = c[i] - a[i];
        }
        assertEq(LibUint256Array.add(a, b), c);
        assertEq(LibUint256Array.sub(c, b), a);
        assertEq(LibUint256Array.sub(c, a), b);
    }
}
