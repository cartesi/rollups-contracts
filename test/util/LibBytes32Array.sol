// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

library LibBytes32Array {
    function concat(bytes32[] memory a, bytes32[] memory b)
        internal
        pure
        returns (bytes32[] memory c)
    {
        // Create an array with sum of lengths of A and B
        c = new bytes32[](a.length + b.length);

        // Copy array A onto C
        for (uint256 i; i < a.length; ++i) {
            c[i] = a[i];
        }

        // Copy array B onto C after the first |A| elements
        for (uint256 i; i < b.length; ++i) {
            c[a.length + i] = b[i];
        }
    }

    error InvalidArrayIndex(bytes32[] array, uint256 index);

    function split(bytes32[] calldata array, uint256 index)
        external
        pure
        returns (bytes32[] memory head, bytes32[] memory tail)
    {
        if (index <= array.length) {
            head = array[:index];
            tail = array[index:];
        } else {
            revert InvalidArrayIndex(array, index);
        }
    }
}
