// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

library LibInput {
    /// @notice Compute the hash of an input.
    /// @param sender The input sender address
    /// @param blockNumber The block number
    /// @param blockTimestamp The block timestamp
    /// @param index The input index
    /// @param payload The input payload
    /// @return The input hash
    function computeInputHash(
        address sender,
        uint256 blockNumber,
        uint256 blockTimestamp,
        uint256 index,
        bytes calldata payload
    ) internal pure returns (bytes32) {
        bytes memory metadata = encodeInputMetadata(
            sender,
            blockNumber,
            blockTimestamp,
            index
        );

        return keccak256(abi.encode(keccak256(metadata), keccak256(payload)));
    }

    /// @notice Encode the metadata of an input.
    /// @param sender The input sender address
    /// @param blockNumber The block number
    /// @param blockTimestamp The block timestamp
    /// @param index The input index
    /// @return The encoded input metadata
    function encodeInputMetadata(
        address sender,
        uint256 blockNumber,
        uint256 blockTimestamp,
        uint256 index
    ) internal pure returns (bytes memory) {
        return abi.encode(sender, blockNumber, blockTimestamp, 0, index);
    }
}
