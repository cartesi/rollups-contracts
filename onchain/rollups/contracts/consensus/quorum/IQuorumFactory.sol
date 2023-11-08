// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {Quorum} from "./Quorum.sol";
import {IHistory} from "../../history/IHistory.sol";

/// @title Quorum Factory interface
interface IQuorumFactory {
    // Events

    /// @notice A new quorum was deployed.
    /// @param quorum The quorum
    /// @param history The history
    /// @dev MUST be triggered on a successful call to `newQuorum`.
    event QuorumCreated(Quorum quorum, IHistory history);

    // Permissionless functions

    /// @notice Deploy a new quorum.
    /// @param _validators the list of validators
    /// @param _shares the list of shares
    /// @param _history the history contract
    /// @return The quorum
    /// @dev On success, MUST emit a `QuorumCreated` event.
    function newQuorum(
        address[] calldata _validators,
        uint256[] calldata _shares,
        IHistory _history
    ) external returns (Quorum);

    /// @notice Deploy a new quorum deterministically.
    /// @param _validators the list of validators
    /// @param _shares the list of shares
    /// @param _history the history contract
    /// @param _salt The salt used to deterministically generate the quorum address
    /// @return The quorum
    /// @dev On success, MUST emit a `QuorumCreated` event.
    function newQuorum(
        address[] calldata _validators,
        uint256[] calldata _shares,
        IHistory _history,
        bytes32 _salt
    ) external returns (Quorum);

    /// @notice Calculate the address of a quorum to be deployed deterministically.
    /// @param _validators the list of validators
    /// @param _shares the list of shares
    /// @param _history the history address
    /// @param _salt The salt used to deterministically generate the quorum address
    /// @return The deterministic quorum address
    /// @dev Beware that only the `newQuorum` function with the `_salt` parameter
    ///      is able to deterministically deploy a quorum.
    function calculateQuorumAddress(
        address[] calldata _validators,
        uint256[] calldata _shares,
        address _history,
        bytes32 _salt
    ) external view returns (address);
}
