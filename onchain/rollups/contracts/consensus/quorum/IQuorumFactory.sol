// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {Quorum} from "./Quorum.sol";
import {IHistory} from "../../history/IHistory.sol";

/// @title Quorum factory interface
interface IQuorumFactory {
    // Events

    /// @notice A new quorum was deployed.
    /// @param validators The initial set of quorum validators
    /// @param quorum The quorum
    /// @param shares The initial distribution of shares amongst validators
    /// @param history The history contract
    /// @dev MUST be triggered on a successful call to `newQuorum`.
    event QuorumCreated(
        address[] validators,
        Quorum quorum,
        uint256[] shares,
        IHistory history
    );

    // Permissionless functions

    /// @notice Deploy a new quorum.
    /// @param _validators The initial set of quorum validators
    /// @param _shares The initial distribution of shares amongst validators
    /// @param _history The history contract
    /// @return The quorum
    /// @dev On success, MUST emit an `QuorumCreated` event.
    function newQuorum(
        address[] calldata _validators,
        uint256[] calldata _shares,
        IHistory _history
    ) external returns (Quorum);

    /// @notice Deploy a new quorum deterministically.
    /// @param _validators The initial set of quorum validators
    /// @param _shares The initial distribution of shares amongst validators
    /// @param _history The history contract
    /// @param _salt The salt used to deterministically generate the quorum address
    /// @return The quorum
    /// @dev On success, MUST emit an `QuorumCreated` event.
    function newQuorum(
        address[] calldata _validators,
        uint256[] calldata _shares,
        IHistory _history,
        bytes32 _salt
    ) external returns (Quorum);

    /// @notice Calculate the address of an quorum to be deployed deterministically.
    /// @param _validators The initial set of quorum validators
    /// @param _shares The initial distribution of shares amongst validators
    /// @param _history The history contract
    /// @param _salt The salt used to deterministically generate the quorum address
    /// @return The deterministic quorum address
    /// @dev Beware that only the `newQuorum` function with the `_salt` parameter
    ///      is able to deterministically deploy an quorum.
    function calculateQuorumAddress(
        address[] calldata _validators,
        uint256[] calldata _shares,
        IHistory _history,
        bytes32 _salt
    ) external view returns (address);
}
