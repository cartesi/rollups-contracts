// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {Quorum} from "./Quorum.sol";
import {IHistory} from "../../history/IHistory.sol";


/// @title Quorum factory interface
interface IQuorumFactory {
    // Events

    /// @notice A new quorum was deployed.
    /// @param _quorumValidators The initial set of quorum validators
    /// @param quorum The quorum
    /// @dev MUST be triggered on a successful call to `newQuorum`.
    event QuorumCreated(address[] _quorumValidators, Quorum quorum);

    // Permissionless functions

    /// @notice Deploy a new quorum.
    /// @param _quorumValidators The initial set of quorum validators
    /// @return The quorum
    /// @dev On success, MUST emit an `QuorumCreated` event.
    function newQuorum(
        address[] calldata _quorumValidators,
        uint256[] calldata _shares,
        IHistory _history
    ) external returns (Quorum);

    /// @notice Deploy a new quorum deterministically.
    /// @param _quorumValidators The initial set of quorum validators
    /// @param _salt The salt used to deterministically generate the quorum address
    /// @return The quorum
    /// @dev On success, MUST emit an `QuorumCreated` event.
    function newQuorum(
        address[] calldata _quorumValidators,
        uint256[] calldata _shares,
        IHistory _history,
        bytes32 _salt
    ) external returns (Quorum);

    /// @notice Calculate the address of an quorum to be deployed deterministically.
    /// @param _quorumValidators The initial set of quorum validators
    /// @param _salt The salt used to deterministically generate the quorum address
    /// @return The deterministic quorum address
    /// @dev Beware that only the `newQuorum` function with the `_salt` parameter
    ///      is able to deterministically deploy an quorum.
    function calculateQuorumAddress(
        address[] calldata _quorumValidators,
        uint256[] calldata _shares,
        IHistory _history,
        bytes32 _salt
    ) external view returns (address);
}