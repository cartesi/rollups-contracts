// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

/// @title Inputs
/// @notice Defines the signatures of inputs.
interface Inputs {
    /// @notice An advance request from an EVM-compatible blockchain to a Cartesi Machine.
    /// @param chainId The chain ID
    /// @param appContract The application contract address
    /// @param msgSender The address of whoever sent the input
    /// @param blockNumber The number of the block in which the input was added
    /// @param blockTimestamp The timestamp of the block in which the input was added
    /// @param prevRandao The latest RANDAO mix of the post beacon state of the previous block
    /// @param index The index of the input in the input box
    /// @param payload The payload provided by the message sender
    /// @dev See EIP-4399 for safe usage of `prevRandao`.
    function EvmAdvance(
        uint256 chainId,
        address appContract,
        address msgSender,
        uint256 blockNumber,
        uint256 blockTimestamp,
        uint256 prevRandao,
        uint256 index,
        bytes calldata payload
    ) external;
}
