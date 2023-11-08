// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {Quorum} from "./Quorum.sol";
import {IQuorumFactory} from "./IQuorumFactory.sol";
import {History} from "../../history/History.sol";
import {IHistoryFactory} from "../../history/IHistoryFactory.sol";

/// @title Quorum-History Pair Factory Interface
interface IQuorumHistoryPairFactory {
    // Events

    /// @notice The factory was created.
    /// @param quorumFactory The underlying `Quorum` factory
    /// @param historyFactory The underlying `History` factory
    /// @dev MUST be emitted on construction.
    event QuorumHistoryPairFactoryCreated(
        IQuorumFactory quorumFactory,
        IHistoryFactory historyFactory
    );

    // Permissionless functions

    /// @notice Get the factory used to deploy `Quorum` contracts
    /// @return The `Quorum` factory
    function getQuorumFactory() external view returns (IQuorumFactory);

    /// @notice Get the factory used to deploy `History` contracts
    /// @return The `History` factory
    function getHistoryFactory() external view returns (IHistoryFactory);

    /// @notice Deploy a new quorum-history pair.
    /// @param _validators the list of validators
    /// @param _shares the list of shares
    /// @return The quorum
    /// @return The history
    function newQuorumHistoryPair(
        address[] calldata _validators,
        uint256[] calldata _shares
    ) external returns (Quorum, History);

    /// @notice Deploy a new quorum-history pair deterministically.
    /// @param _validators the list of validators
    /// @param _shares the list of shares
    /// @param _salt The salt used to deterministically generate the quorum-history pair address
    /// @return The quorum
    /// @return The history
    function newQuorumHistoryPair(
        address[] calldata _validators,
        uint256[] calldata _shares,
        bytes32 _salt
    ) external returns (Quorum, History);

    /// @notice Calculate the address of an quorum-history pair to be deployed deterministically.
    /// @param _validators the list of validators
    /// @param _shares the list of shares
    /// @param _salt The salt used to deterministically generate the quorum-history address pair
    /// @return The deterministic quorum address
    /// @return The deterministic history address
    /// @dev Beware that only the `newQuorumHistoryPair` function with the `_salt` parameter
    ///      is able to deterministically deploy an quorum-history pair.
    function calculateQuorumHistoryAddressPair(
        address[] calldata _validators,
        uint256[] calldata _shares,
        bytes32 _salt
    ) external view returns (address, address);
}
