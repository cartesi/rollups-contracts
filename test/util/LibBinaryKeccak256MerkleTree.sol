// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {LibBinaryMerkleTree} from "../../src/library/LibBinaryMerkleTree.sol";
import {LibKeccak256} from "../../src/library/LibKeccak256.sol";

import {CompressedNode} from "../util/CompressedNode.sol";
import {LibBinaryMerkleTreeHelper} from "../util/LibBinaryMerkleTreeHelper.sol";

library LibBinaryKeccak256MerkleTree {
    using LibBinaryMerkleTree for bytes;
    using LibBinaryMerkleTree for bytes32[];
    using LibBinaryMerkleTreeHelper for bytes;
    using LibBinaryMerkleTreeHelper for bytes[];
    using LibBinaryMerkleTreeHelper for bytes32[];
    using LibBinaryMerkleTreeHelper for CompressedNode[];

    function merkleRootAfterReplacement(
        bytes32[] calldata sibs,
        uint256 nodeIndex,
        bytes32 node
    ) external pure returns (bytes32) {
        return sibs.merkleRootAfterReplacement(nodeIndex, node, nodeFromChildren);
    }

    function merkleRoot(
        bytes calldata data,
        uint256 log2DriveSize,
        uint256 log2DataBlockSize
    ) external pure returns (bytes32) {
        return data.merkleRoot(
            log2DriveSize, log2DataBlockSize, leafFromDataAt, nodeFromChildren
        );
    }

    function merkleRootFromNodes(
        bytes32[] calldata nodes,
        bytes32 defaultNode,
        uint256 height
    ) external pure returns (bytes32) {
        return nodes.merkleRootFromNodes(defaultNode, height, nodeFromChildren);
    }

    function merkleRootFromNodes(
        CompressedNode[] calldata compressedNodes,
        bytes32 defaultNode,
        uint256 height
    ) external pure returns (bytes32) {
        return compressedNodes.merkleRootFromNodes(defaultNode, height, nodeFromChildren);
    }

    function siblings(
        bytes32[] calldata nodes,
        bytes32 defaultNode,
        uint256 nodeIndex,
        uint256 height
    ) external pure returns (bytes32[] memory) {
        return nodes.siblings(defaultNode, nodeIndex, height, nodeFromChildren);
    }

    function siblings(
        CompressedNode[] calldata compressedNodes,
        bytes32 defaultNode,
        uint256 nodeIndex,
        uint256 height
    ) external pure returns (bytes32[] memory) {
        return compressedNodes.siblings(defaultNode, nodeIndex, height, nodeFromChildren);
    }

    function toLeaves(bytes[] calldata dataBlocks)
        external
        pure
        returns (bytes32[] memory)
    {
        return dataBlocks.toLeaves(leafFromDataBlock);
    }

    function splitIntoBlocks(bytes calldata data, uint256 dataBlockSize)
        external
        pure
        returns (bytes[] memory)
    {
        return data.splitIntoBlocks(dataBlockSize);
    }

    function compress(bytes32[] calldata nodes)
        external
        pure
        returns (CompressedNode[] memory)
    {
        return nodes.compress();
    }

    function decompress(CompressedNode[] calldata compressedNodes)
        external
        pure
        returns (bytes32[] memory)
    {
        return compressedNodes.decompress();
    }

    function decompressedLength(CompressedNode[] calldata compressedNodes)
        external
        pure
        returns (uint256)
    {
        return compressedNodes.decompressedLength();
    }

    function parentLevel(bytes32[] calldata nodes, bytes32 defaultNode)
        external
        pure
        returns (bytes32[] memory)
    {
        return nodes.parentLevel(defaultNode, nodeFromChildren);
    }

    function at(bytes32[] calldata nodes, uint256 index, bytes32 defaultNode)
        external
        pure
        returns (bytes32)
    {
        return nodes.at(index, defaultNode);
    }

    function parentLevel(CompressedNode[] calldata compressedNodes, bytes32 defaultNode)
        external
        pure
        returns (CompressedNode[] memory)
    {
        return compressedNodes.parentLevel(defaultNode, nodeFromChildren);
    }

    function at(
        CompressedNode[] calldata compressedNodes,
        uint256 index,
        bytes32 defaultNode
    ) external pure returns (bytes32) {
        return compressedNodes.at(index, defaultNode);
    }

    function leafFromDataBlock(bytes memory data) internal pure returns (bytes32) {
        return LibKeccak256.hashBytes(data);
    }

    function leafFromDataAt(
        bytes memory data,
        uint256 dataBlockIndex,
        uint256 dataBlockSize
    ) internal pure returns (bytes32) {
        return LibKeccak256.hashBlock(data, dataBlockIndex, dataBlockSize);
    }

    function nodeFromChildren(bytes32 leaf, bytes32 right)
        internal
        pure
        returns (bytes32)
    {
        return LibKeccak256.hashPair(leaf, right);
    }
}
