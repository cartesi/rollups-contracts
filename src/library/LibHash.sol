// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

library LibHash {
    /// @notice An efficient implementation of
    /// `keccak256(abi.encode(a, b))`
    /// that does not allocate or expand memory.
    function efficientKeccak256(bytes32 a, bytes32 b)
        internal
        pure
        returns (bytes32 node)
    {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            node := keccak256(0x00, 0x40)
        }
    }
}
