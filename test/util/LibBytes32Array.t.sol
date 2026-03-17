// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Test} from "forge-std-1.9.6/src/Test.sol";

import {LibBytes32Array} from "./LibBytes32Array.sol";

contract LibBytes32ArrayTest is Test {
    using LibBytes32Array for bytes32[];

    function testConcat(bytes32[] calldata a, bytes32[] calldata b) external pure {
        bytes32[] memory c = a.concat(b);
        assertEq(c.length, a.length + b.length);
        for (uint256 i; i < c.length; ++i) {
            if (i < a.length) {
                assertEq(c[i], a[i]);
            } else {
                assertEq(c[i], b[i - a.length]);
            }
        }
        (bytes32[] memory head, bytes32[] memory tail) = c.split(a.length);
        assertEq(head, a);
        assertEq(tail, b);
    }

    function testSplit(bytes32[] calldata array) external {
        uint256 index = vm.randomUint(0, array.length);
        (bytes32[] memory head, bytes32[] memory tail) = array.split(index);
        assertEq(array.length, head.length + tail.length);
        assertEq(head.length, index);
        for (uint256 i; i < array.length; ++i) {
            if (i < head.length) {
                assertEq(array[i], head[i]);
            } else {
                assertEq(array[i], tail[i - head.length]);
            }
        }
        assertEq(head.concat(tail), array);
    }
}
