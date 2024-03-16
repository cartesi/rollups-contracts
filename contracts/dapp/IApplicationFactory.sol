// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {Application} from "./Application.sol";
import {IConsensus} from "../consensus/IConsensus.sol";
import {IInputBox} from "../inputs/IInputBox.sol";
import {IPortal} from "../portals/IPortal.sol";

/// @title Application Factory interface
interface IApplicationFactory {
    // Events

    /// @notice A new application was deployed.
    /// @param consensus The initial consensus contract
    /// @param inputBox The input box contract
    /// @param portals The portals supported by the application
    /// @param appOwner The initial application owner
    /// @param templateHash The initial machine state hash
    /// @param appContract The application contract
    /// @dev MUST be triggered on a successful call to `newApplication`.
    event ApplicationCreated(
        IConsensus indexed consensus,
        IInputBox inputBox,
        IPortal[] portals,
        address appOwner,
        bytes32 templateHash,
        Application appContract
    );

    // Permissionless functions

    /// @notice Deploy a new application.
    /// @param consensus The initial consensus contract
    /// @param inputBox The input box contract
    /// @param portals The portals supported by the application
    /// @param appOwner The initial application owner
    /// @param templateHash The initial machine state hash
    /// @return The application
    /// @dev On success, MUST emit an `ApplicationCreated` event.
    function newApplication(
        IConsensus consensus,
        IInputBox inputBox,
        IPortal[] calldata portals,
        address appOwner,
        bytes32 templateHash
    ) external returns (Application);

    /// @notice Deploy a new application deterministically.
    /// @param consensus The initial consensus contract
    /// @param inputBox The input box contract
    /// @param portals The portals supported by the application
    /// @param appOwner The initial application owner
    /// @param templateHash The initial machine state hash
    /// @param salt The salt used to deterministically generate the application contract address
    /// @return The application
    /// @dev On success, MUST emit an `ApplicationCreated` event.
    function newApplication(
        IConsensus consensus,
        IInputBox inputBox,
        IPortal[] calldata portals,
        address appOwner,
        bytes32 templateHash,
        bytes32 salt
    ) external returns (Application);

    /// @notice Calculate the address of an application contract to be deployed deterministically.
    /// @param consensus The initial consensus contract
    /// @param inputBox The input box contract
    /// @param portals The portals supported by the application
    /// @param appOwner The initial application owner
    /// @param templateHash The initial machine state hash
    /// @param salt The salt used to deterministically generate the application contract address
    /// @return The deterministic application contract address
    /// @dev Beware that only the `newApplication` function with the `salt` parameter
    ///      is able to deterministically deploy an application.
    function calculateApplicationAddress(
        IConsensus consensus,
        IInputBox inputBox,
        IPortal[] calldata portals,
        address appOwner,
        bytes32 templateHash,
        bytes32 salt
    ) external view returns (address);
}
