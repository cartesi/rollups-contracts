// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Test} from "forge-std-1.9.6/src/Test.sol";

import {LibHash} from "src/library/LibHash.sol";
import {LibBinaryMerkleTree} from "src/library/LibBinaryMerkleTree.sol";

import {console} from "forge-std-1.9.6/src/console.sol";

import {LibBinaryMerkleTreeHelper} from "../util/LibBinaryMerkleTreeHelper.sol";

/// @dev Uses Keccak-256
library ExternalLibBinaryMerkleTree {
    using LibBinaryMerkleTree for bytes32[];

    function merkleRootAfterReplacement(
        bytes32[] calldata sibs,
        uint256 index,
        bytes32 leaf
    ) external pure returns (bytes32) {
        return sibs.merkleRootAfterReplacement(index, leaf, LibHash.efficientKeccak256);
    }
}

contract LibBinaryMerkleTreeTest is Test {
    using ExternalLibBinaryMerkleTree for bytes32[];
    using LibBinaryMerkleTreeHelper for bytes32[];

    function testMinHeight() external pure {
        assertEq(_minHeight(0), 0);
        assertEq(_minHeight(1), 0);
        assertEq(_minHeight(2), 1);
        assertEq(_minHeight(3), 2);
        assertEq(_minHeight(4), 2);
        assertEq(_minHeight(5), 3);
        // skip...
        for (uint256 i = 3; i < 256; ++i) {
            assertEq(_minHeight(1 << i), i);
            assertEq(_minHeight((1 << i) + 1), i + 1);
        }
        // skip...
        assertEq(_minHeight(type(uint256).max), 256);
    }

    function testParent() external pure {
        assertEq(
            _parent(bytes32(0), bytes32(0)),
            0xad3228b676f7d3cd4284a5443f17f1962b36e491b30a40b2405849e597ba5fb5
        );
        assertEq(
            _parent(bytes32(uint256(0xdeadbeef)), bytes32(uint256(0xfafafafa))),
            0xda8d1c323302c4549981015475e50eefb2e7df73b8ecf1bde639cee25c8ad669
        );
    }

    function testEfficientKeccak256Fuzzy(bytes32 a, bytes32 b) external pure {
        assertEq(_parent(a, b), LibHash.efficientKeccak256(a, b));
    }

    function testMerkleRootAfterReplacementHeightZero(bytes32 leaf) external {
        bytes32[] memory siblings;

        siblings = new bytes32[](0);

        // With height zero, the leaf is the merkle root
        assertEq(siblings.merkleRootAfterReplacement(0, leaf), leaf);

        vm.expectRevert(LibBinaryMerkleTree.InvalidNodeIndex.selector);
        siblings.merkleRootAfterReplacement(1, leaf);
    }

    function testMerkleRootAfterReplacementHeightOne(bytes32 sibling, bytes32 leaf)
        external
    {
        bytes32[] memory siblings;

        siblings = new bytes32[](1);
        siblings[0] = sibling;

        assertEq(siblings.merkleRootAfterReplacement(0, leaf), _parent(leaf, sibling));

        assertEq(siblings.merkleRootAfterReplacement(1, leaf), _parent(sibling, leaf));

        vm.expectRevert(LibBinaryMerkleTree.InvalidNodeIndex.selector);
        siblings.merkleRootAfterReplacement(2, leaf);
    }

    function testMerkleRootAfterReplacementHeightTwo(
        bytes32 firstSibling,
        bytes32 secondSibling,
        bytes32 leaf
    ) external {
        bytes32[] memory siblings;

        siblings = new bytes32[](2);
        siblings[0] = firstSibling;
        siblings[1] = secondSibling;

        assertEq(
            siblings.merkleRootAfterReplacement(0, leaf),
            _parent(_parent(leaf, firstSibling), secondSibling)
        );

        assertEq(
            siblings.merkleRootAfterReplacement(1, leaf),
            _parent(_parent(firstSibling, leaf), secondSibling)
        );

        assertEq(
            siblings.merkleRootAfterReplacement(2, leaf),
            _parent(secondSibling, _parent(leaf, firstSibling))
        );

        assertEq(
            siblings.merkleRootAfterReplacement(3, leaf),
            _parent(secondSibling, _parent(firstSibling, leaf))
        );

        vm.expectRevert(LibBinaryMerkleTree.InvalidNodeIndex.selector);
        siblings.merkleRootAfterReplacement(4, leaf);
    }

    function testMerkleRootAfterReplacementFuzzy(
        bytes32[] calldata leaves,
        uint256 height,
        uint256 index
    ) external pure {
        height = _boundHeight(height, leaves.length);
        index = _boundBits(index, height);

        bytes32 leaf;

        if (index < leaves.length) {
            leaf = leaves[index];
        }

        bytes32 defaultNode;

        bytes32 root =
            leaves.merkleRootFromNodes(defaultNode, height, LibHash.efficientKeccak256);

        bytes32[] memory siblings =
            leaves.siblings(defaultNode, index, height, LibHash.efficientKeccak256);

        bytes32 newRoot = siblings.merkleRootAfterReplacement(index, leaf);

        assertEq(root, newRoot);
    }

    function _parent(bytes32 left, bytes32 right) internal pure returns (bytes32) {
        return keccak256(abi.encode(left, right));
    }

    function _minHeight(uint256 n) internal pure returns (uint256) {
        for (uint256 height; height < 256; ++height) {
            if (n <= (1 << height)) {
                return height;
            }
        }
        return 256;
    }

    function _boundHeight(uint256 height, uint256 n) internal pure returns (uint256) {
        return bound(height, _minHeight(n), 256);
    }

    function _boundBits(uint256 x, uint256 nbits) internal pure returns (uint256) {
        if (nbits < 256) {
            return x >> (256 - nbits);
        } else {
            return x;
        }
    }
}
