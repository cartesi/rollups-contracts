// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";

import {LibMerkle32} from "src/library/LibMerkle32.sol";

import "forge-std/console.sol";

library ExternalLibMerkle32 {
    using LibMerkle32 for bytes32[];

    function merkleRoot(bytes32[] calldata leaves, uint256 height)
        external
        pure
        returns (bytes32)
    {
        return leaves.merkleRoot(height);
    }

    function siblings(bytes32[] calldata leaves, uint256 index, uint256 height)
        external
        pure
        returns (bytes32[] memory)
    {
        return leaves.siblings(index, height);
    }

    function merkleRootAfterReplacement(
        bytes32[] calldata sibs,
        uint256 index,
        bytes32 leaf
    ) external pure returns (bytes32) {
        return sibs.merkleRootAfterReplacement(index, leaf);
    }

    function at(bytes32[] memory nodes, uint256 index, bytes32 defaultNode)
        internal
        pure
        returns (bytes32)
    {
        return nodes.at(index, defaultNode);
    }
}

contract LibMerkle32Test is Test {
    using ExternalLibMerkle32 for bytes32[];

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

    function testParentFuzzy(bytes32 a, bytes32 b) external pure {
        assertEq(_parent(a, b), LibMerkle32.parent(a, b));
    }

    function testAt(bytes32 firstNode, bytes32 secondNode, bytes32 defaultNode)
        external
        pure
    {
        bytes32[] memory leaves = new bytes32[](0);

        assertEq(leaves.at(0, defaultNode), defaultNode);

        leaves = new bytes32[](1);
        leaves[0] = firstNode;

        assertEq(leaves.at(0, defaultNode), firstNode);
        assertEq(leaves.at(1, defaultNode), defaultNode);

        leaves = new bytes32[](2);
        leaves[0] = firstNode;
        leaves[1] = secondNode;

        assertEq(leaves.at(0, defaultNode), firstNode);
        assertEq(leaves.at(1, defaultNode), secondNode);
        assertEq(leaves.at(2, defaultNode), defaultNode);
    }

    function testMerkleRootZeroLeavesZeroHeight(bytes32 leftLeaf, bytes32 rightLeaf)
        external
    {
        bytes32[] memory leaves;

        leaves = new bytes32[](0);

        assertEq(leaves.merkleRoot(0), bytes32(0));

        leaves = new bytes32[](1);
        leaves[0] = leftLeaf;

        // The merkle root is the leaf itself
        assertEq(leaves.merkleRoot(0), leftLeaf);

        leaves = new bytes32[](2);
        leaves[0] = leftLeaf;
        leaves[1] = rightLeaf;

        vm.expectRevert("LibMerkle32: too many leaves");
        leaves.merkleRoot(0);
    }

    function testMerkleRootHeightOne(
        bytes32 leftLeaf,
        bytes32 rightLeaf,
        bytes32 extraLeaf
    ) external {
        bytes32[] memory leaves;

        leaves = new bytes32[](0);

        assertEq(leaves.merkleRoot(1), _parent(bytes32(0), bytes32(0)));

        leaves = new bytes32[](1);
        leaves[0] = leftLeaf;

        // Leaves are filled from left to right
        assertEq(leaves.merkleRoot(1), _parent(leftLeaf, bytes32(0)));

        leaves = new bytes32[](2);
        leaves[0] = leftLeaf;
        leaves[1] = rightLeaf;

        assertEq(leaves.merkleRoot(1), _parent(leftLeaf, rightLeaf));

        leaves = new bytes32[](3);
        leaves[0] = leftLeaf;
        leaves[1] = rightLeaf;
        leaves[2] = extraLeaf;

        vm.expectRevert("LibMerkle32: too many leaves");
        leaves.merkleRoot(1);
    }

    function testMerkleRootHeightTwo(
        bytes32 firstLeaf,
        bytes32 secondLeaf,
        bytes32 thirdLeaf,
        bytes32 fourthLeaf,
        bytes32 extraLeaf
    ) external {
        bytes32[] memory leaves;

        leaves = new bytes32[](0);

        assertEq(
            leaves.merkleRoot(2),
            _parent(_parent(bytes32(0), bytes32(0)), _parent(bytes32(0), bytes32(0)))
        );

        leaves = new bytes32[](1);
        leaves[0] = firstLeaf;

        assertEq(
            leaves.merkleRoot(2),
            _parent(_parent(firstLeaf, bytes32(0)), _parent(bytes32(0), bytes32(0)))
        );

        leaves = new bytes32[](2);
        leaves[0] = firstLeaf;
        leaves[1] = secondLeaf;

        assertEq(
            leaves.merkleRoot(2),
            _parent(_parent(firstLeaf, secondLeaf), _parent(bytes32(0), bytes32(0)))
        );

        leaves = new bytes32[](3);
        leaves[0] = firstLeaf;
        leaves[1] = secondLeaf;
        leaves[2] = thirdLeaf;

        assertEq(
            leaves.merkleRoot(2),
            _parent(_parent(firstLeaf, secondLeaf), _parent(thirdLeaf, bytes32(0)))
        );

        leaves = new bytes32[](4);
        leaves[0] = firstLeaf;
        leaves[1] = secondLeaf;
        leaves[2] = thirdLeaf;
        leaves[3] = fourthLeaf;

        assertEq(
            leaves.merkleRoot(2),
            _parent(_parent(firstLeaf, secondLeaf), _parent(thirdLeaf, fourthLeaf))
        );

        leaves = new bytes32[](5);
        leaves[0] = firstLeaf;
        leaves[1] = secondLeaf;
        leaves[2] = thirdLeaf;
        leaves[3] = fourthLeaf;
        leaves[4] = extraLeaf;

        vm.expectRevert("LibMerkle32: too many leaves");
        leaves.merkleRoot(2);
    }

    function testSiblingsHeightZero(bytes32 leftLeaf, bytes32 rightLeaf) external {
        bytes32[] memory siblings;
        bytes32[] memory leaves;

        leaves = new bytes32[](0);

        // Zero height yields zero siblings
        siblings = leaves.siblings(0, 0);
        assertEq(siblings.length, 0);

        vm.expectRevert("LibMerkle32: index out of bounds");
        leaves.siblings(1, 0);

        leaves = new bytes32[](1);
        leaves[0] = leftLeaf;

        siblings = leaves.siblings(0, 0);
        assertEq(siblings.length, 0);

        vm.expectRevert("LibMerkle32: index out of bounds");
        leaves.siblings(1, 0);

        leaves = new bytes32[](2);
        leaves[0] = leftLeaf;
        leaves[1] = rightLeaf;

        vm.expectRevert("LibMerkle32: too many leaves");
        leaves.siblings(0, 0);

        vm.expectRevert("LibMerkle32: index out of bounds");
        leaves.siblings(1, 0);
    }

    function testSiblingsHeightOne(bytes32 leftLeaf, bytes32 rightLeaf, bytes32 extraLeaf)
        external
    {
        bytes32[] memory siblings;
        bytes32[] memory leaves;

        leaves = new bytes32[](0);

        siblings = leaves.siblings(0, 1);
        assertEq(siblings.length, 1);
        assertEq(siblings[0], bytes32(0));

        siblings = leaves.siblings(1, 1);
        assertEq(siblings.length, 1);
        assertEq(siblings[0], bytes32(0));

        vm.expectRevert("LibMerkle32: index out of bounds");
        leaves.siblings(2, 1);

        leaves = new bytes32[](1);
        leaves[0] = leftLeaf;

        siblings = leaves.siblings(0, 1);
        assertEq(siblings.length, 1);
        assertEq(siblings[0], bytes32(0));

        siblings = leaves.siblings(1, 1);
        assertEq(siblings.length, 1);
        assertEq(siblings[0], leftLeaf);

        vm.expectRevert("LibMerkle32: index out of bounds");
        leaves.siblings(2, 1);

        leaves = new bytes32[](2);
        leaves[0] = leftLeaf;
        leaves[1] = rightLeaf;

        siblings = leaves.siblings(0, 1);
        assertEq(siblings.length, 1);
        assertEq(siblings[0], rightLeaf);

        siblings = leaves.siblings(1, 1);
        assertEq(siblings.length, 1);
        assertEq(siblings[0], leftLeaf);

        vm.expectRevert("LibMerkle32: index out of bounds");
        leaves.siblings(2, 1);

        leaves = new bytes32[](3);
        leaves[0] = leftLeaf;
        leaves[1] = rightLeaf;
        leaves[2] = extraLeaf;

        vm.expectRevert("LibMerkle32: too many leaves");
        leaves.siblings(0, 1);

        vm.expectRevert("LibMerkle32: too many leaves");
        leaves.siblings(1, 1);

        vm.expectRevert("LibMerkle32: index out of bounds");
        leaves.siblings(2, 1);
    }

    function testSiblingsHeightTwo(
        bytes32 firstLeaf,
        bytes32 secondLeaf,
        bytes32 thirdLeaf,
        bytes32 fourthLeaf
    ) external {
        bytes32[] memory siblings;
        bytes32[] memory leaves;

        leaves = new bytes32[](0);

        for (uint256 i; i < 4; ++i) {
            siblings = leaves.siblings(i, 2);
            assertEq(siblings.length, 2);
            assertEq(siblings[0], bytes32(0));
            assertEq(siblings[1], _parent(bytes32(0), bytes32(0)));
        }

        vm.expectRevert("LibMerkle32: index out of bounds");
        leaves.siblings(4, 2);

        leaves = new bytes32[](1);
        leaves[0] = firstLeaf;

        siblings = leaves.siblings(0, 2);
        assertEq(siblings.length, 2);
        assertEq(siblings[0], bytes32(0));
        assertEq(siblings[1], _parent(bytes32(0), bytes32(0)));

        siblings = leaves.siblings(1, 2);
        assertEq(siblings.length, 2);
        assertEq(siblings[0], firstLeaf);
        assertEq(siblings[1], _parent(bytes32(0), bytes32(0)));

        for (uint256 i = 2; i < 4; ++i) {
            siblings = leaves.siblings(i, 2);
            assertEq(siblings.length, 2);
            assertEq(siblings[0], bytes32(0));
            assertEq(siblings[1], _parent(firstLeaf, bytes32(0)));
        }

        vm.expectRevert("LibMerkle32: index out of bounds");
        leaves.siblings(4, 2);

        leaves = new bytes32[](2);
        leaves[0] = firstLeaf;
        leaves[1] = secondLeaf;

        siblings = leaves.siblings(0, 2);
        assertEq(siblings.length, 2);
        assertEq(siblings[0], secondLeaf);
        assertEq(siblings[1], _parent(bytes32(0), bytes32(0)));

        siblings = leaves.siblings(1, 2);
        assertEq(siblings.length, 2);
        assertEq(siblings[0], firstLeaf);
        assertEq(siblings[1], _parent(bytes32(0), bytes32(0)));

        for (uint256 i = 2; i < 4; ++i) {
            siblings = leaves.siblings(i, 2);
            assertEq(siblings.length, 2);
            assertEq(siblings[0], bytes32(0));
            assertEq(siblings[1], _parent(firstLeaf, secondLeaf));
        }

        vm.expectRevert("LibMerkle32: index out of bounds");
        leaves.siblings(4, 2);

        leaves = new bytes32[](3);
        leaves[0] = firstLeaf;
        leaves[1] = secondLeaf;
        leaves[2] = thirdLeaf;

        siblings = leaves.siblings(0, 2);
        assertEq(siblings.length, 2);
        assertEq(siblings[0], secondLeaf);
        assertEq(siblings[1], _parent(thirdLeaf, bytes32(0)));

        siblings = leaves.siblings(1, 2);
        assertEq(siblings.length, 2);
        assertEq(siblings[0], firstLeaf);
        assertEq(siblings[1], _parent(thirdLeaf, bytes32(0)));

        siblings = leaves.siblings(2, 2);
        assertEq(siblings.length, 2);
        assertEq(siblings[0], bytes32(0));
        assertEq(siblings[1], _parent(firstLeaf, secondLeaf));

        siblings = leaves.siblings(3, 2);
        assertEq(siblings.length, 2);
        assertEq(siblings[0], thirdLeaf);
        assertEq(siblings[1], _parent(firstLeaf, secondLeaf));

        vm.expectRevert("LibMerkle32: index out of bounds");
        leaves.siblings(4, 2);

        leaves = new bytes32[](4);
        leaves[0] = firstLeaf;
        leaves[1] = secondLeaf;
        leaves[2] = thirdLeaf;
        leaves[3] = fourthLeaf;

        siblings = leaves.siblings(0, 2);
        assertEq(siblings.length, 2);
        assertEq(siblings[0], secondLeaf);
        assertEq(siblings[1], _parent(thirdLeaf, fourthLeaf));

        siblings = leaves.siblings(1, 2);
        assertEq(siblings.length, 2);
        assertEq(siblings[0], firstLeaf);
        assertEq(siblings[1], _parent(thirdLeaf, fourthLeaf));

        siblings = leaves.siblings(2, 2);
        assertEq(siblings.length, 2);
        assertEq(siblings[0], fourthLeaf);
        assertEq(siblings[1], _parent(firstLeaf, secondLeaf));

        siblings = leaves.siblings(3, 2);
        assertEq(siblings.length, 2);
        assertEq(siblings[0], thirdLeaf);
        assertEq(siblings[1], _parent(firstLeaf, secondLeaf));

        vm.expectRevert("LibMerkle32: index out of bounds");
        leaves.siblings(4, 2);
    }

    function testMerkleRootAfterReplacementHeightZero(bytes32 leaf) external {
        bytes32[] memory siblings;

        siblings = new bytes32[](0);

        // With height zero, the leaf is the merkle root
        assertEq(siblings.merkleRootAfterReplacement(0, leaf), leaf);

        vm.expectRevert("LibMerkle32: index out of bounds");
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

        vm.expectRevert("LibMerkle32: index out of bounds");
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

        vm.expectRevert("LibMerkle32: index out of bounds");
        siblings.merkleRootAfterReplacement(4, leaf);
    }

    function testMerkleRootAfterReplacementFuzzy(
        bytes32[] calldata leaves,
        uint256 height,
        uint256 index
    ) external pure {
        height = _boundHeight(height, leaves.length);
        index = _boundBits(index, height);

        bytes32 leaf = leaves.at(index, bytes32(0));

        bytes32 root = leaves.merkleRoot(height);

        bytes32[] memory siblings = leaves.siblings(index, height);

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
