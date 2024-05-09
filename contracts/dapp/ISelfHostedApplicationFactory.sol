// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.8;

import {Authority} from "../consensus/authority/Authority.sol";
import {IAuthorityFactory} from "../consensus/authority/IAuthorityFactory.sol";
import {Application} from "./Application.sol";
import {IApplicationFactory} from "./IApplicationFactory.sol";
import {IInputBox} from "../inputs/IInputBox.sol";
import {IPortal} from "../portals/IPortal.sol";

/// @title Self-hosted Application Factory interface
interface ISelfHostedApplicationFactory {
    /// @notice Get the factory used to deploy `Authority` contracts
    /// @return The authority factory
    function getAuthorityFactory() external view returns (IAuthorityFactory);

    /// @notice Get the factory used to deploy `Application` contracts
    /// @return The application factory
    function getApplicationFactory()
        external
        view
        returns (IApplicationFactory);

    /// @notice Deploy new application and authority contracts deterministically.
    /// @param authorityOwner The initial authority owner
    /// @param inputBox The input box contract
    /// @param portals The portals supported by the application
    /// @param appOwner The initial Application owner
    /// @param templateHash The initial machine state hash
    /// @param salt The salt used to deterministically generate the addresses
    /// @return The application contract
    /// @return The authority contract
    function deployContracts(
        address authorityOwner,
        IInputBox inputBox,
        IPortal[] calldata portals,
        address appOwner,
        bytes32 templateHash,
        bytes32 salt
    ) external returns (Application, Authority);

    /// @notice Calculate the addresses of the application and authority contracts
    /// to be deployed deterministically.
    /// @param authorityOwner The initial authority owner
    /// @param inputBox The input box contract
    /// @param portals The portals supported by the application
    /// @param appOwner The initial Application owner
    /// @param templateHash The initial machine state hash
    /// @param salt The salt used to deterministically generate the addresses
    /// @return The application address
    /// @return The authority address
    function calculateAddresses(
        address authorityOwner,
        IInputBox inputBox,
        IPortal[] calldata portals,
        address appOwner,
        bytes32 templateHash,
        bytes32 salt
    ) external view returns (address, address);
}
