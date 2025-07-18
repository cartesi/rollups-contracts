// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

library LibKeccak256 {
    /// @notice Hash a variable-length byte array.
    /// @param b The byte array
    function hashBytes(bytes memory b) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := keccak256(add(b, 0x20), mload(b))
        }
    }

    /// @notice Hash a data block at a given index and of a given size.
    /// @param data The data
    /// @param dataBlockIndex The data block index
    /// @param dataBlockSize The data block size
    /// @dev If the data block is too large, an out-of-memory error might be raised.
    /// @dev If the data block index is too big, an arithmetic error might be raised.
    function hashBlock(bytes memory data, uint256 dataBlockIndex, uint256 dataBlockSize)
        internal
        pure
        returns (bytes32 result)
    {
        uint256 start = dataBlockIndex * dataBlockSize;
        uint256 end = start + dataBlockSize;
        uint256 dataLength = data.length;
        if (end <= dataLength) {
            // Block is completely within data and can be hashed in-place, without memory allocation
            assembly {
                result := keccak256(add(add(data, 0x20), start), dataBlockSize)
            }
        } else {
            // Block is partially or completely outside data and requires memory allocation
            bytes memory dataBlock = new bytes(dataBlockSize);
            if (start < dataLength) {
                // Block is partially within data and requires a memory-copy operation
                assembly {
                    mcopy(
                        add(dataBlock, 0x20),
                        add(add(data, 0x20), start),
                        sub(dataLength, start)
                    )
                }
            }
            // Block is then hashed with a known size
            assembly {
                result := keccak256(add(dataBlock, 0x20), dataBlockSize)
            }
        }
    }

    /// @notice Hash a pair of 32-byte values.
    /// @dev Equivalent to keccak256(abi.encode(a, b)).
    /// @dev Uses assembly to avoid memory allocation or expansion.
    function hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            result := keccak256(0x00, 0x40)
        }
    }
}
