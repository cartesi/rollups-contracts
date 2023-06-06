// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {Authority} from "./Authority.sol";
import {IAuthorityFactory} from "./IAuthorityFactory.sol";
import {History} from "../../history/History.sol";
import {IHistoryFactory} from "../../history/IHistoryFactory.sol";

/// @title Authority-History Pair Factory interface
interface IAuthorityHistoryPairFactory {
    // Events

    /// @notice The factory was created.
    /// @param authorityFactory The underlying `Authority` factory
    /// @param historyFactory The underlying `History` factory
    /// @dev MUST be emitted on construction.
    event AuthorityHistoryPairFactoryCreated(
        IAuthorityFactory authorityFactory,
        IHistoryFactory historyFactory
    );

    // Permissionless functions

    /// @notice Get the factory used to deploy `Authority` contracts
    /// @return The `Authority` factory
    function getAuthorityFactory() external view returns (IAuthorityFactory);

    /// @notice Get the factory used to deploy `History` contracts
    /// @return The `History` factory
    function getHistoryFactory() external view returns (IHistoryFactory);

    /// @notice Deploy a new authority-history pair.
    /// @param _authorityOwner The initial authority owner
    /// @return The authority
    /// @return The history
    function newAuthorityHistoryPair(
        address _authorityOwner
    ) external returns (Authority, History);

    /// @notice Deploy a new authority-history pair deterministically.
    /// @param _authorityOwner The initial authority owner
    /// @param _salt The salt used to deterministically generate the authority-history pair address
    /// @return The authority
    /// @return The history
    function newAuthorityHistoryPair(
        address _authorityOwner,
        bytes32 _salt
    ) external returns (Authority, History);

    /// @notice Calculate the address of an authority-history pair to be deployed deterministically.
    /// @param _authorityOwner The initial authority owner
    /// @param _salt The salt used to deterministically generate the authority-history address pair
    /// @return The deterministic authority address
    /// @return The deterministic history address
    /// @dev Beware that only the `newAuthorityHistoryPair` function with the `_salt` parameter
    ///      is able to deterministically deploy an authority-history pair.
    function calculateAuthorityHistoryAddressPair(
        address _authorityOwner,
        bytes32 _salt
    ) external view returns (address, address);
}
