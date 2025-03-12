// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @notice Provides valid outputs Merkle roots for validation.
/// @dev ERC-165 can be used to determine whether this contract also
/// supports any other interface (e.g. for submitting claims).
interface IConsensus is IERC165 {
    /// @notice Check whether an outputs Merkle root is valid.
    /// @param appContract The application contract address
    /// @param outputsMerkleRoot The outputs Merkle root
    function isOutputsMerkleRootValid(
        address appContract,
        bytes32 outputsMerkleRoot
    ) external view returns (bool);
}
