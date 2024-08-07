// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {Quorum} from "./Quorum.sol";

/// @title Quorum Factory interface
interface IQuorumFactory {
    // Events

    /// @notice A new quorum was deployed.
    /// @param quorum The quorum
    /// @dev MUST be triggered on a successful call to `newQuorum`.
    event QuorumCreated(Quorum quorum);

    // Permissionless functions

    /// @notice Deploy a new quorum.
    /// @param validators the list of validators
    /// @param epochLength The epoch length
    /// @return The quorum
    /// @dev On success, MUST emit a `QuorumCreated` event.
    /// @dev Duplicates in the `validators` array are ignored.
    /// @dev Reverts if the epoch length is zero.
    function newQuorum(
        address[] calldata validators,
        uint256 epochLength
    ) external returns (Quorum);

    /// @notice Deploy a new quorum deterministically.
    /// @param validators the list of validators
    /// @param epochLength The epoch length
    /// @param salt The salt used to deterministically generate the quorum address
    /// @return The quorum
    /// @dev On success, MUST emit a `QuorumCreated` event.
    /// @dev Duplicates in the `validators` array are ignored.
    /// @dev Reverts if the epoch length is zero.
    function newQuorum(
        address[] calldata validators,
        uint256 epochLength,
        bytes32 salt
    ) external returns (Quorum);

    /// @notice Calculate the address of a quorum to be deployed deterministically.
    /// @param validators the list of validators
    /// @param epochLength The epoch length
    /// @param salt The salt used to deterministically generate the quorum address
    /// @return The deterministic quorum address
    /// @dev Beware that only the `newQuorum` function with the `salt` parameter
    ///      is able to deterministically deploy a quorum.
    function calculateQuorumAddress(
        address[] calldata validators,
        uint256 epochLength,
        bytes32 salt
    ) external view returns (address);
}
