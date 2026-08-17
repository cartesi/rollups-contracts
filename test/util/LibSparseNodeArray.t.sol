// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {Test} from "forge-std-1.9.6/src/Test.sol";

import {LibMath} from "../../src/library/LibMath.sol";

import {LibBinaryKeccak256MerkleTree} from "../util/LibBinaryKeccak256MerkleTree.sol";
import {CompressedNode} from "./CompressedNode.sol";
import {LibSparseNodeArray} from "./LibSparseNodeArray.sol";
import {SparseNode} from "./SparseNode.sol";

contract LibSparseNodeArrayTest is Test {
    using LibSparseNodeArray for SparseNode[];
    using LibBinaryKeccak256MerkleTree for bytes32[];
    using LibBinaryKeccak256MerkleTree for CompressedNode[];

    function testToCompressedNodeArray(bytes32 defaultValue) external {
        uint256 sparseNodeCount = vm.randomUint(1, 10);

        SparseNode[] memory sparseNodes = new SparseNode[](sparseNodeCount);

        uint256 minIndex;
        for (uint256 i; i < sparseNodes.length; ++i) {
            bytes32 value = bytes32(vm.randomUint());
            uint256 maxIndex = type(uint256).max - (sparseNodes.length - i);
            uint256 index = vm.randomUint(minIndex, maxIndex);
            uint256 maxExtra = maxIndex - index;
            uint256 extra = vm.randomUint(0, maxExtra);
            sparseNodes[i] = SparseNode({value: value, index: index, extra: extra});
            minIndex = index + extra + 1;
        }

        _shuffleInPlace(sparseNodes);

        CompressedNode[] memory compressedNodes =
            sparseNodes.toCompressedNodeArray(defaultValue);

        uint256 nodeCount = compressedNodes.decompressedLength();
        uint256 minHeight = LibMath.ceilLog2(nodeCount);
        uint256 height = vm.randomUint(minHeight, 256);

        uint256 sparseNodeIndex = vm.randomUint(0, sparseNodes.length - 1);
        SparseNode memory sparseNode = sparseNodes[sparseNodeIndex];
        bytes32 node = sparseNode.value;
        uint256 nodeIndex = sparseNode.index + vm.randomUint(0, sparseNode.extra);
        bytes32[] memory siblings =
            compressedNodes.siblings(defaultValue, nodeIndex, height);

        assertEq(
            compressedNodes.merkleRootFromNodes(defaultValue, height),
            siblings.merkleRootAfterReplacement(nodeIndex, node)
        );
    }

    function _shuffleInPlace(SparseNode[] memory array) internal {
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
}
