// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @notice Each application has its own stream of inputs.
/// See the `IInputBox` interface for calldata-based on-chain data availability.
/// @notice When an input is fed to the application, it may yield several outputs.
/// @notice Since genesis, a Merkle tree of all outputs ever produced is maintained
/// both inside and outside the Cartesi Machine.
interface IConsensus is IERC165 {
    /// @notice Check whether an outputs Merkle root is valid.
    /// @param appContract The application contract address
    /// @param outputsMerkleRoot The outputs Merkle root
    function isOutputsMerkleRootValid(
        address appContract,
        bytes32 outputsMerkleRoot
    ) external view returns (bool);
}
