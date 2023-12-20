// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {Application} from "./Application.sol";
import {IConsensus} from "../consensus/IConsensus.sol";
import {IInputBox} from "../inputs/IInputBox.sol";
import {IInputRelay} from "../inputs/IInputRelay.sol";

/// @title Application Factory interface
interface IApplicationFactory {
    // Events

    /// @notice A new application was deployed.
    /// @param consensus The initial consensus contract
    /// @param inputBox The input box contract
    /// @param inputRelays The input relays
    /// @param appOwner The initial application owner
    /// @param templateHash The initial machine state hash
    /// @param app The application
    /// @dev MUST be triggered on a successful call to `newApplication`.
    event ApplicationCreated(
        IConsensus indexed consensus,
        IInputBox inputBox,
        IInputRelay[] inputRelays,
        address appOwner,
        bytes32 templateHash,
        Application app
    );

    // Permissionless functions

    /// @notice Deploy a new application.
    /// @param _consensus The initial consensus contract
    /// @param _inputBox The input box contract
    /// @param _inputRelays The input relays
    /// @param _appOwner The initial application owner
    /// @param _templateHash The initial machine state hash
    /// @return The application
    /// @dev On success, MUST emit an `ApplicationCreated` event.
    function newApplication(
        IConsensus _consensus,
        IInputBox _inputBox,
        IInputRelay[] calldata _inputRelays,
        address _appOwner,
        bytes32 _templateHash
    ) external returns (Application);

    /// @notice Deploy a new application deterministically.
    /// @param _consensus The initial consensus contract
    /// @param _inputBox The input box contract
    /// @param _inputRelays The input relays
    /// @param _appOwner The initial application owner
    /// @param _templateHash The initial machine state hash
    /// @param _salt The salt used to deterministically generate the application address
    /// @return The application
    /// @dev On success, MUST emit an `ApplicationCreated` event.
    function newApplication(
        IConsensus _consensus,
        IInputBox _inputBox,
        IInputRelay[] calldata _inputRelays,
        address _appOwner,
        bytes32 _templateHash,
        bytes32 _salt
    ) external returns (Application);

    /// @notice Calculate the address of an application to be deployed deterministically.
    /// @param _consensus The initial consensus contract
    /// @param _inputBox The input box contract
    /// @param _inputRelays The input relays
    /// @param _appOwner The initial application owner
    /// @param _templateHash The initial machine state hash
    /// @param _salt The salt used to deterministically generate the application address
    /// @return The deterministic application address
    /// @dev Beware that only the `newApplication` function with the `_salt` parameter
    ///      is able to deterministically deploy an application.
    function calculateApplicationAddress(
        IConsensus _consensus,
        IInputBox _inputBox,
        IInputRelay[] calldata _inputRelays,
        address _appOwner,
        bytes32 _templateHash,
        bytes32 _salt
    ) external view returns (address);
}
