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
