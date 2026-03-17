// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {BinaryMerkleTreeErrors} from "../common/BinaryMerkleTreeErrors.sol";
import {CanonicalMachine} from "../common/CanonicalMachine.sol";
import {LibMath} from "./LibMath.sol";

library LibBinaryMerkleTree {
    using LibMath for uint256;

    /// @notice Log2 of the maximum data block size.
    /// @dev The data block must still be smaller than the drive.
    /// We limit the size of data blocks because of the block gas limit.
    uint256 constant LOG2_MAX_DATA_BLOCK_SIZE = 12;

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
        require(
            (nodeIndex >> height) == 0,
            BinaryMerkleTreeErrors.InvalidNodeIndex(nodeIndex, height)
        );
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
        require(
            log2DriveSize <= CanonicalMachine.LOG2_MEMORY_SIZE,
            BinaryMerkleTreeErrors.DriveTooLarge(
                log2DriveSize, CanonicalMachine.LOG2_MEMORY_SIZE
            )
        );
        require(
            log2DataBlockSize <= LOG2_MAX_DATA_BLOCK_SIZE,
            BinaryMerkleTreeErrors.DataBlockTooLarge(
                log2DataBlockSize, LOG2_MAX_DATA_BLOCK_SIZE
            )
        );

        uint256 driveSize = 1 << log2DriveSize;

        require(
            data.length <= driveSize,
            BinaryMerkleTreeErrors.DriveSmallerThanData(driveSize, data.length)
        );
        require(
            log2DataBlockSize <= log2DriveSize,
            BinaryMerkleTreeErrors.DriveSmallerThanDataBlock(
                log2DriveSize, log2DataBlockSize
            )
        );

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
        uint256 stackDepth; // depth of stack (length of stack sub-array)
        uint256 numOfJoins; // number of hashes of the same level on stack
        uint256 topStackLevel; // level of hash on top of the stack

        while (numOfHashes < numOfLeaves) {
            if ((numOfHashes << log2DataBlockSize) < data.length) {
                // we still have data blocks to hash
                stack[stackDepth] = leafFromDataAt(data, numOfHashes, dataBlockSize);
                numOfHashes++;

                numOfJoins = numOfHashes;
            } else {
                // since padding happens in LibBytes.getBlock,
                // we only need to complete the stack with
                // pristine Merkle roots
                topStackLevel = numOfHashes.ctz();

                stack[stackDepth] = pristineNodes[topStackLevel];

                //Empty Tree Hash summarizes many hashes
                numOfHashes = numOfHashes + (1 << topStackLevel);
                numOfJoins = numOfHashes >> topStackLevel;
            }

            stackDepth++;

            // while there are joins, hash top of stack together
            while (numOfJoins & 1 == 0) {
                bytes32 h2 = stack[stackDepth - 1];
                bytes32 h1 = stack[stackDepth - 2];

                stack[stackDepth - 2] = nodeFromChildren(h1, h2);
                stackDepth = stackDepth - 1; // remove hashes from stack

                numOfJoins = numOfJoins >> 1;
            }
        }

        require(
            stackDepth == 1, BinaryMerkleTreeErrors.UnexpectedFinalStackDepth(stackDepth)
        );

        return stack[0];
    }
}
