// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.0;

import {LibMath} from "./LibMath.sol";
import {LibMerkleConstants} from "./LibMerkleConstants.sol";
import {LibPristineMerkleTree} from "./LibPristineMerkleTree.sol";

/// @title Merkle library for trees of 32-byte leaves that operates on byte arrays
/// @notice This library is meant for computing Merkle roots.
/// @notice Each Merkle tree is assumed to have `2^height` leaves.
/// @notice Nodes are concatenated pairwise and hashed with `keccak256`.
/// @notice Siblings are in bottom-up order, from leaf to root.
library LibMerkle {
    using LibMath for uint256;

    /// @notice Compute the hash of the concatenation of two 32-byte values.
    /// @param a The first value
    /// @param b The second value
    /// @return c The result of `keccak256(abi.encodePacked(a, b))`
    /// @dev Uses assembly for better performance.
    function join(bytes32 a, bytes32 b) internal pure returns (bytes32 c) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            c := keccak256(0x00, 0x40)
        }
    }

    /// @notice Get the log2 of the smallest drive that fits data of the provided size.
    /// @param dataLength the byte array length
    /// @dev If the data is smaller than the drive, it is padded with zeros.
    /// @dev The smallest tree covers at least one leaf.
    /// @dev See `LibMerkleConstants` for leaf size.
    function getMinLog2SizeOfDrive(uint256 dataLength) internal pure returns (uint256) {
        return dataLength.log2clp().max(LibMerkleConstants.LOG2_LEAF_SIZE);
    }

    /// @notice Get the Merkle root of a byte array.
    /// @param data the byte array
    /// @param log2SizeOfDrive log2 of size of the drive
    /// @dev If data is smaller than the drive, it is padded with zeros.
    /// @dev See `LibMerkleConstants` for leaf size.
    function getMerkleRootFromBytes(bytes memory data, uint256 log2SizeOfDrive)
        internal
        pure
        returns (bytes32)
    {
        require(
            log2SizeOfDrive >= LibMerkleConstants.LOG2_LEAF_SIZE,
            "Drive smaller than leaf"
        );
        require(
            log2SizeOfDrive <= LibMerkleConstants.LOG2_MEMORY_SIZE,
            "Drive larger than memory"
        );

        uint256 log2NumOfLeavesInDrive =
            log2SizeOfDrive - LibMerkleConstants.LOG2_LEAF_SIZE;

        // if data is empty, then return node from pristine Merkle tree
        if (data.length == 0) {
            return LibPristineMerkleTree.getNodeAtHeight(log2NumOfLeavesInDrive);
        }

        uint256 numOfLeavesInDrive = 1 << log2NumOfLeavesInDrive;

        require(
            data.length <= (numOfLeavesInDrive << LibMerkleConstants.LOG2_LEAF_SIZE),
            "Data larger than drive"
        );

        // Note: This is a very generous stack depth.
        bytes32[] memory stack = new bytes32[](2 + log2NumOfLeavesInDrive);

        uint256 numOfHashes; // total number of leaves covered up until now
        uint256 stackLength; // total length of stack
        uint256 numOfJoins; // number of hashes of the same level on stack
        uint256 topStackLevel; // level of hash on top of the stack

        while (numOfHashes < numOfLeavesInDrive) {
            if ((numOfHashes << LibMerkleConstants.LOG2_LEAF_SIZE) < data.length) {
                // we still have leaves to hash
                stack[stackLength] = getHashOfLeafAtIndex(data, numOfHashes);
                numOfHashes++;

                numOfJoins = numOfHashes;
            } else {
                // since padding happens in getHashOfLeafAtIndex function
                // we only need to complete the stack with pre-computed
                // hash(0), hash(hash(0),hash(0)) and so on
                topStackLevel = numOfHashes.ctz();

                stack[stackLength] = LibPristineMerkleTree.getNodeAtHeight(topStackLevel);

                //Empty Tree Hash summarizes many hashes
                numOfHashes = numOfHashes + (1 << topStackLevel);
                numOfJoins = numOfHashes >> topStackLevel;
            }

            stackLength++;

            // while there are joins, hash top of stack together
            while (numOfJoins & 1 == 0) {
                bytes32 h2 = stack[stackLength - 1];
                bytes32 h1 = stack[stackLength - 2];

                stack[stackLength - 2] = join(h1, h2);
                stackLength = stackLength - 1; // remove hashes from stack

                numOfJoins = numOfJoins >> 1;
            }
        }

        require(stackLength == 1, "stack error");

        return stack[0];
    }

    /// @notice Get the hash of a leaf from a byte array by its index.
    /// @param data the byte array
    /// @param leafIndex the leaf index
    /// @dev The data is assumed to be followed by an infinite sequence of zeroes.
    /// @dev See `LibMerkleConstants` for leaf size.
    function getHashOfLeafAtIndex(bytes memory data, uint256 leafIndex)
        internal
        pure
        returns (bytes32)
    {
        uint256 start = leafIndex << LibMerkleConstants.LOG2_LEAF_SIZE;
        if (start < data.length) {
            uint256 leafSize = 1 << LibMerkleConstants.LOG2_LEAF_SIZE;
            uint256 end = data.length.min(start + leafSize);
            bytes memory leaf = new bytes(leafSize);
            assembly {
                mcopy(add(leaf, 0x20), add(add(data, 0x20), start), sub(end, start))
            }
            return keccak256(leaf);
        } else {
            return LibPristineMerkleTree.getNodeAtHeight(0);
        }
    }
}
