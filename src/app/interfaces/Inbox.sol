// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

/// @notice Provides data availability of inputs.
/// @dev Keeps an append-only list of input Merkle roots.
/// Off-chain, inputs can be retrieved through `InputAdded` events.
/// On-chain, input Merkle roots can be retrieved through the `getInputMerkleRoot` function.
/// The Merkle root of an input is computed as follows:
/// First, the input is split into 256-bit data blocks from the LSB to the MSB.
/// If the last data block is not 256-bit wide, it is right-padded with zeroes.
/// Second, data blocks are hashed with Keccak-256 to become the leaves of the Merkle tree.
/// If the leaves do not amount to a power of 2, they are completed with the Keccak-256 of the zeroed data block.
/// Third, the nodes of a binary Merkle tree are constructed bottom-up from the leaves.
/// Internal nodes are the Keccak-256 of the left child concatenated with the right child.
/// Once we reach the root node, we have effectively computed the input Merkle root.
interface Inbox {
    /// @notice MUST trigger when an input is added.
    /// @param inputIndex The input index
    /// @param input The input
    /// @dev Input indices are zero-based and incremental.
    event InputAdded(uint256 indexed inputIndex, bytes input);

    /// @notice Input is too large.
    /// @param inputLength The input length
    /// @param maxInputLength The maximum input length
    error InputTooLarge(uint256 inputLength, uint256 maxInputLength);

    /// @notice Get the number of inputs.
    function getNumberOfInputs() external view returns (uint256);

    /// @notice Get the number of inputs before the current block.
    function getNumberOfInputsBeforeCurrentBlock() external view returns (uint256);

    /// @notice Get the Merkle root of an input by its index.
    /// @param inputIndex The input index
    /// @dev The provided index must be valid.
    /// Valid input indices are within the range `[0, N)`.
    /// See  `getNumberOfInputs` for the value of `N`.
    function getInputMerkleRoot(uint256 inputIndex) external view returns (bytes32);

    /// @notice Send an input.
    /// @param payload The input payload
    /// @return The Merkle root of the input
    /// @dev MUST fire an `InputAdded` event.
    /// MAY raise an `InputTooLarge` error.
    /// The payload is composed with blockchain metadata to become an input.
    function addInput(bytes calldata payload) external returns (bytes32);
}
