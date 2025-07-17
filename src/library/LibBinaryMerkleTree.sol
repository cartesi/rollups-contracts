// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {LibMath} from "./LibMath.sol";

library LibBinaryMerkleTree {
    using LibMath for uint256;

    /// @notice Log2 of the maximum drive size.
    uint256 constant LOG2_MAX_DRIVE_SIZE = 64;

    /// @notice Log2 of the maximum data block size.
    /// @dev The data block must still be smaller than the drive.
    uint256 constant LOG2_MAX_DATA_BLOCK_SIZE = 12;

    /// @notice The provided node index is invalid.
    /// @dev The index should be less than `2^height`.
    error InvalidNodeIndex();

    /// @notice A drive size smaller than the data block size was provided.
    error DriveSmallerThanDataBlock();

    /// @notice A drive too small to fit the data was provided.
    error DriveSmallerThanData();

    /// @notice A data block size too large was provided.
    error DataBlockTooLarge();

    /// @notice A drive size too large was provided.
    error DriveTooLarge();

    /// @notice An unexpected stack error occurred.
    /// @dev Its final depth was not 1.
    error UnexpectedStackError();

    /// @notice Compute the root of a Merkle tree after replacing one of its nodes.
    /// @param sibs The siblings of the node in bottom-up order
    /// @param nodeIndex The index of the node
    /// @param node The new node
    /// @param nodeFromChildren The function that computes nodes from their children
    /// @return The root hash of the new Merkle tree
    /// @dev Level of node is deduced by the length of the siblings array.
    /// @dev Raises an `InvalidNodeIndex` error if an invalid node index is provided.
    function merkleRootAfterReplacement(
        bytes32[] calldata sibs,
        uint256 nodeIndex,
        bytes32 node,
        function(bytes32, bytes32) pure returns (bytes32) nodeFromChildren
    ) internal pure returns (bytes32) {
        uint256 height = sibs.length;
        require((nodeIndex >> height) == 0, InvalidNodeIndex());
        for (uint256 i; i < height; ++i) {
            bool isNodeLeftChild = ((nodeIndex >> i) & 1 == 0);
            bytes32 nodeSibling = sibs[i];
            node = isNodeLeftChild
                ? nodeFromChildren(node, nodeSibling)
                : nodeFromChildren(nodeSibling, node);
        }
        return node;
    }

    /// @notice Get the Merkle root of a byte array.
    /// @param data The byte array
    /// @param log2DriveSize The log2 of the drive size
    /// @param log2DataBlockSize The log2 of the data block size
    /// @param leafFromDataAt The function that computes leaves from data blocks
    /// @param nodeFromChildren The function that computes nodes from their children
    /// @dev Data blocks are right-padded with zeros if necessary.
    /// @dev leafFromDataAt receives the data, the block index, and the block size
    function merkleRoot(
        bytes memory data,
        uint256 log2DriveSize,
        uint256 log2DataBlockSize,
        function(bytes memory, uint256, uint256) pure returns (bytes32) leafFromDataAt,
        function(bytes32, bytes32) pure returns (bytes32) nodeFromChildren
    ) internal pure returns (bytes32) {
        require(log2DriveSize <= LOG2_MAX_DRIVE_SIZE, DriveTooLarge());
        require(log2DataBlockSize <= LOG2_MAX_DATA_BLOCK_SIZE, DataBlockTooLarge());

        uint256 driveSize = 1 << log2DriveSize;

        require(data.length <= driveSize, DriveSmallerThanData());
        require(log2DataBlockSize <= log2DriveSize, DriveSmallerThanDataBlock());

        uint256 merkleTreeHeight = log2DriveSize - log2DataBlockSize;
        uint256 numOfLeaves = 1 << merkleTreeHeight;
        uint256 dataBlockSize = 1 << log2DataBlockSize;

        bytes32[] memory pristineNodes = new bytes32[](1 + merkleTreeHeight);

        // compute pristine nodes
        {
            bytes32 node = leafFromDataAt(new bytes(dataBlockSize), 0, dataBlockSize);
            pristineNodes[0] = node;
            for (uint256 i = 1; i <= merkleTreeHeight; ++i) {
                node = nodeFromChildren(node, node);
                pristineNodes[i] = node;
            }
        }

        // if data is empty, then return pristine Merkle root
        if (data.length == 0) {
            return pristineNodes[merkleTreeHeight];
        }

        // Note: This is a very generous stack depth.
        bytes32[] memory stack = new bytes32[](2 + merkleTreeHeight);

        uint256 numOfHashes; // total number of leaves covered up until now
        uint256 stackLength; // total length of stack
        uint256 numOfJoins; // number of hashes of the same level on stack
        uint256 topStackLevel; // level of hash on top of the stack

        while (numOfHashes < numOfLeaves) {
            if ((numOfHashes << log2DataBlockSize) < data.length) {
                // we still have data blocks to hash
                stack[stackLength] = leafFromDataAt(data, numOfHashes, dataBlockSize);
                numOfHashes++;

                numOfJoins = numOfHashes;
            } else {
                // since padding happens in LibBytes.getBlock,
                // we only need to complete the stack with
                // pristine Merkle roots
                topStackLevel = numOfHashes.ctz();

                stack[stackLength] = pristineNodes[topStackLevel];

                //Empty Tree Hash summarizes many hashes
                numOfHashes = numOfHashes + (1 << topStackLevel);
                numOfJoins = numOfHashes >> topStackLevel;
            }

            stackLength++;

            // while there are joins, hash top of stack together
            while (numOfJoins & 1 == 0) {
                bytes32 h2 = stack[stackLength - 1];
                bytes32 h1 = stack[stackLength - 2];

                stack[stackLength - 2] = nodeFromChildren(h1, h2);
                stackLength = stackLength - 1; // remove hashes from stack

                numOfJoins = numOfJoins >> 1;
            }
        }

        require(stackLength == 1, UnexpectedStackError());

        return stack[0];
    }
}
