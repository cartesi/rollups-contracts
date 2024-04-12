// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.13;

import {Authority} from "../consensus/authority/Authority.sol";
import {CartesiDApp} from "./CartesiDApp.sol";
import {History} from "../history/History.sol";
import {IAuthorityHistoryPairFactory} from "../consensus/authority/IAuthorityHistoryPairFactory.sol";
import {ICartesiDAppFactory} from "./ICartesiDAppFactory.sol";

/// @title Self-hosted Application Factory interface
interface ISelfHostedApplicationFactory {
    /// @notice Get the factory used to deploy `Authority` and `History` contracts
    /// @return The authority-history pair factory
    function getAuthorityHistoryPairFactory()
        external
        view
        returns (IAuthorityHistoryPairFactory);

    /// @notice Get the factory used to deploy `CartesiDApp` contracts
    /// @return The application factory
    function getApplicationFactory()
        external
        view
        returns (ICartesiDAppFactory);

    /// @notice Deploy new application, authority and history contracts deterministically.
    /// @param _authorityOwner The initial authority owner
    /// @param _dappOwner The initial DApp owner
    /// @param _templateHash The initial machine state hash
    /// @param _salt The salt used to deterministically generate the addresses
    /// @return The application contract
    /// @return The authority contract
    /// @return The history contract
    function deployContracts(
        address _authorityOwner,
        address _dappOwner,
        bytes32 _templateHash,
        bytes32 _salt
    ) external returns (CartesiDApp, Authority, History);

    /// @notice Calculate the addresses of the application, authority and history contracts
    /// to be deployed deterministically.
    /// @param _authorityOwner The initial authority owner
    /// @param _dappOwner The initial DApp owner
    /// @param _templateHash The initial machine state hash
    /// @param _salt The salt used to deterministically generate the addresses
    /// @return The application address
    /// @return The authority address
    /// @return The history address
    function calculateAddresses(
        address _authorityOwner,
        address _dappOwner,
        bytes32 _templateHash,
        bytes32 _salt
    ) external view returns (address, address, address);
}
