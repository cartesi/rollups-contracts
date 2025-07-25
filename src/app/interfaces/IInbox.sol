// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

/// @notice Provides data availability of inputs.
/// @notice Keeps an append-only list of input Merkle roots.
/// @notice Off-chain, inputs can be retrieved through `InputAdded` events.
/// @notice On-chain, input Merkle roots can be retrieved through the `getInputMerkleRoot` function.
/// @notice The Merkle root of an input is computed as follows:
/// @notice First, the input is split into 256-bit data blocks from the LSB to the MSB.
/// @notice If the last data block is not 256-bit wide, it is right-padded with zeroes.
/// @notice Second, data blocks are hashed with Keccak-256 to become the leaves of the Merkle tree.
/// @notice If the leaves do not amount to a power of 2, they are completed with the Keccak-256 of the zeroed data block.
/// @notice Third, the nodes of a binary Merkle tree are constructed bottom-up from the leaves.
/// @notice Internal nodes are the Keccak-256 of the left child concatenated with the right child.
/// @notice Once we reach the root node, we have effectively computed the input Merkle root.
interface IInbox {
    /// @notice MUST trigger when an input is added.
    /// @param index The input index
    /// @param input The input
    event InputAdded(uint256 indexed index, bytes input);

    /// @notice Input is too large.
    /// @param inputLength The input length
    /// @param maxInputLength The maximum input length
    error InputTooLarge(uint256 inputLength, uint256 maxInputLength);

    /// @notice Send an input.
    /// @param payload The input payload
    /// @return The Merkle root of the input
    /// @dev MUST fire an `InputAdded` event.
    function addInput(bytes calldata payload)
        external
        returns (bytes32);

    /// @notice Get the number of inputs.
    function getNumberOfInputs() external view returns (uint256);

    /// @notice Get the Merkle root of an input by its index.
    /// @param index The input index
    /// @dev The provided index must be valid.
    function getInputMerkleRoot(uint256 index)
        external
        view
        returns (bytes32);
}
