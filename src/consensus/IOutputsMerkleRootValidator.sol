// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {IERC165} from "@openzeppelin-contracts-5.2.0/utils/introspection/IERC165.sol";

/// @notice Provides valid outputs Merkle roots for validation.
/// @dev ERC-165 can be used to determine whether this contract also
/// supports any other interface (e.g. for submitting claims).
interface IOutputsMerkleRootValidator is IERC165 {
    /// @notice Check whether an outputs Merkle root is valid.
    /// @param appContract The application contract address
    /// @param outputsMerkleRoot The outputs Merkle root
    function isOutputsMerkleRootValid(address appContract, bytes32 outputsMerkleRoot)
        external
        view
        returns (bool);

    /// @notice Get the last finalized machine Merkle root.
    /// @param appContract The application contract address
    /// @dev Returns zero if no machine merkle root has been finalized yet
    /// for that particular application. This should not be a problem given
    /// that the pre-image Keccak-256 hash of zero is unknown.
    function getLastFinalizedMachineMerkleRoot(address appContract)
        external
        view
        returns (bytes32);

    /// @notice Check whether an input was finalized.
    /// @param appContract The application contract address
    /// @param inputIndex The index of the input in the application's input box
    /// @param blockNumber The number of the base-layer block in which the input was added
    /// @return Whether the input was finalized
    /// @dev This function assumes that an input with such an index exists in the input
    /// box of the application, and that it was added in such a base-layer block.
    /// Foreclosed applications can use this function to issue refunds for deposit inputs
    /// that were not finalized.
    function wasInputFinalized(
        address appContract,
        uint256 inputIndex,
        uint256 blockNumber
    ) external view returns (bool);
}
