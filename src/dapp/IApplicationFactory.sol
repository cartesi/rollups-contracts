// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {IVersionGetter} from "../common/IVersionGetter.sol";
import {WithdrawalConfig} from "../common/WithdrawalConfig.sol";
import {IOutputsMerkleRootValidator} from "../consensus/IOutputsMerkleRootValidator.sol";
import {IInputBox} from "../inputs/IInputBox.sol";
import {IApplication} from "./IApplication.sol";
import {IApplicationFactoryErrors} from "./IApplicationFactoryErrors.sol";

/// @title Application Factory interface
interface IApplicationFactory is IVersionGetter, IApplicationFactoryErrors {
    // Events

    /// @notice A new application was deployed.
    /// @param outputsMerkleRootValidator The initial outputs Merkle root validator contract
    /// @param appOwner The initial application owner
    /// @param templateHash The initial machine state hash
    /// @param inputBox The input box contract
    /// @param appContract The application contract
    /// @dev MUST be triggered on a successful call to `newApplication`
    ///      or `newReservedApplication`.
    event ApplicationCreated(
        IOutputsMerkleRootValidator indexed outputsMerkleRootValidator,
        address appOwner,
        bytes32 templateHash,
        IInputBox inputBox,
        WithdrawalConfig withdrawalConfig,
        IApplication appContract
    );

    // Permissionless functions

    /// @notice Deploy a new application.
    /// @param outputsMerkleRootValidator The initial outputs Merkle root validator contract
    /// @param appOwner The initial application owner
    /// @param templateHash The initial machine state hash
    /// @param inputBox The input box contract
    /// @param withdrawalConfig The withdrawal configuration
    /// @return The application
    /// @dev On success, MUST emit an `ApplicationCreated` event.
    /// @dev Reverts if the application owner address is zero.
    /// @dev Reverts with `InvalidWithdrawalConfig` if the withdrawal configuration is invalid.
    function newApplication(
        IOutputsMerkleRootValidator outputsMerkleRootValidator,
        address appOwner,
        bytes32 templateHash,
        IInputBox inputBox,
        WithdrawalConfig calldata withdrawalConfig
    ) external returns (IApplication);

    /// @notice Deploy a new application deterministically.
    /// @param outputsMerkleRootValidator The initial outputs Merkle root validator contract
    /// @param appOwner The initial application owner
    /// @param templateHash The initial machine state hash
    /// @param inputBox The input box contract
    /// @param withdrawalConfig The withdrawal configuration
    /// @param salt The salt used to deterministically generate the application contract address
    /// @return The application
    /// @dev On success, MUST emit an `ApplicationCreated` event.
    /// @dev Reverts if the application owner address is zero.
    /// @dev Reverts with `InvalidWithdrawalConfig` if the withdrawal configuration is invalid.
    /// @dev Reverts with empty error data if the address already contains code,
    ///      consuming 63/64 of the gas left during deployment.
    ///      Users can check the code size of `calculateApplicationAddress` first.
    function newApplication(
        IOutputsMerkleRootValidator outputsMerkleRootValidator,
        address appOwner,
        bytes32 templateHash,
        IInputBox inputBox,
        WithdrawalConfig calldata withdrawalConfig,
        bytes32 salt
    ) external returns (IApplication);

    /// @notice Calculate the address of an application contract to be deployed deterministically.
    /// @param outputsMerkleRootValidator The initial outputs Merkle root validator contract
    /// @param appOwner The initial application owner
    /// @param templateHash The initial machine state hash
    /// @param inputBox The input box contract
    /// @param withdrawalConfig The withdrawal configuration
    /// @param salt The salt used to deterministically generate the application contract address
    /// @return The deterministic application contract address
    /// @dev Beware that only the `newApplication` function with the `salt` parameter
    ///      is able to deploy an application at this address.
    /// @dev The address does not depend on the caller,
    ///      so anyone can deploy any given application.
    ///      Factories that configure applications after deploying them should
    ///      therefore not assume they have deployed an application simply from
    ///      the fact that its pre-calculated address contains some code.
    ///      Such factories should use `newReservedApplication` instead.
    function calculateApplicationAddress(
        IOutputsMerkleRootValidator outputsMerkleRootValidator,
        address appOwner,
        bytes32 templateHash,
        IInputBox inputBox,
        WithdrawalConfig calldata withdrawalConfig,
        bytes32 salt
    ) external view returns (address);

    /// @notice Deploy a new application at an address reserved for the caller.
    /// @param outputsMerkleRootValidator The initial outputs Merkle root validator contract
    /// @param appOwner The initial application owner
    /// @param templateHash The initial machine state hash
    /// @param inputBox The input box contract
    /// @param withdrawalConfig The withdrawal configuration
    /// @param salt The salt used, along with the caller, to generate the address
    /// @return The application
    /// @dev On success, MUST emit an `ApplicationCreated` event.
    /// @dev Reverts if the application owner address is zero.
    /// @dev Reverts with `InvalidWithdrawalConfig` if the withdrawal configuration is invalid.
    /// @dev Reverts with empty error data if the address already contains code,
    ///      consuming 63/64 of the gas left during deployment.
    ///      Users can check the code size of `calculateReservedApplicationAddress` first.
    function newReservedApplication(
        IOutputsMerkleRootValidator outputsMerkleRootValidator,
        address appOwner,
        bytes32 templateHash,
        IInputBox inputBox,
        WithdrawalConfig calldata withdrawalConfig,
        bytes32 salt
    ) external returns (IApplication);

    /// @notice Calculate the address of an application reserved for a given caller.
    /// @param outputsMerkleRootValidator The initial outputs Merkle root validator contract
    /// @param appOwner The initial application owner
    /// @param templateHash The initial machine state hash
    /// @param inputBox The input box contract
    /// @param withdrawalConfig The withdrawal configuration
    /// @param salt The salt used, along with the caller, to generate the address
    /// @param caller The caller of `newReservedApplication`
    /// @return The deterministic application contract address
    /// @dev Only `newReservedApplication`, called by `caller`, deploys at this address.
    function calculateReservedApplicationAddress(
        IOutputsMerkleRootValidator outputsMerkleRootValidator,
        address appOwner,
        bytes32 templateHash,
        IInputBox inputBox,
        WithdrawalConfig calldata withdrawalConfig,
        bytes32 salt,
        address caller
    ) external view returns (address);
}
