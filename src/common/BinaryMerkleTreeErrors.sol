// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

interface BinaryMerkleTreeErrors {
    /// @notice The provided node index is invalid.
    /// @param nodeIndex The node index in its level
    /// @param height The binary Merkle tree height
    /// @dev The node index should be less than `2^{height}`.
    error InvalidNodeIndex(uint256 nodeIndex, uint256 height);

    /// @notice A drive size too large was provided.
    /// @param log2DriveSize The log2 size of the drive
    /// @param maxLog2DriveSize The maximum log2 size of a drive
    error DriveTooLarge(uint256 log2DriveSize, uint256 maxLog2DriveSize);

    /// @notice A data block size too large was provided.
    /// @param log2DataBlockSize The log2 size of the data block
    /// @param maxLog2DataBlockSize The maximum log2 size of a data block
    error DataBlockTooLarge(uint256 log2DataBlockSize, uint256 maxLog2DataBlockSize);

    /// @notice A drive size smaller than the data block size was provided.
    /// @param log2DriveSize The log2 size of the drive
    /// @param log2DataBlockSize The log2 size of the data block
    error DriveSmallerThanDataBlock(uint256 log2DriveSize, uint256 log2DataBlockSize);

    /// @notice A drive too small to fit the data was provided.
    /// @param driveSize The size of the drive
    /// @param dataSize The size of the data
    error DriveSmallerThanData(uint256 driveSize, uint256 dataSize);

    /// @notice An unexpected stack error occurred.
    /// @param stackDepth The final stack depth
    /// @dev Expected final stack depth to be 1.
    error UnexpectedFinalStackDepth(uint256 stackDepth);
}
