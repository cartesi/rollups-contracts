// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {Create2} from "@openzeppelin-contracts-5.2.0/utils/Create2.sol";

import {RollupsContract} from "../common/RollupsContract.sol";
import {WithdrawalConfig} from "../common/WithdrawalConfig.sol";
import {IOutputsMerkleRootValidator} from "../consensus/IOutputsMerkleRootValidator.sol";
import {ISafeErc20Transfer} from "../delegatecall/ISafeErc20Transfer.sol";
import {IInputBox} from "../inputs/IInputBox.sol";
import {LibCreate2Salt} from "../library/LibCreate2Salt.sol";
import {IRefundOutputBuilder} from "../refund/IRefundOutputBuilder.sol";
import {Application} from "./Application.sol";
import {IApplication} from "./IApplication.sol";
import {IApplicationFactory} from "./IApplicationFactory.sol";

/// @title Application Factory
/// @notice Allows anyone to reliably deploy a new `IApplication` contract.
contract ApplicationFactory is IApplicationFactory, RollupsContract {
    IRefundOutputBuilder immutable REFUND_OUTPUT_BUILDER;
    ISafeErc20Transfer immutable SAFE_ERC20_TRANSFER;

    /// @notice Creates an `ApplicationFactory` contract.
    /// @param refundOutputBuilder The refund output builder
    /// @param safeErc20Transfer The safe ERC-20 transfer contract
    constructor(
        IRefundOutputBuilder refundOutputBuilder,
        ISafeErc20Transfer safeErc20Transfer
    ) {
        REFUND_OUTPUT_BUILDER = refundOutputBuilder;
        SAFE_ERC20_TRANSFER = safeErc20Transfer;
    }

    function getSafeErc20Transfer()
        external
        view
        override
        returns (ISafeErc20Transfer safeErc20Transfer)
    {
        return SAFE_ERC20_TRANSFER;
    }

    function newApplication(
        IOutputsMerkleRootValidator outputsMerkleRootValidator,
        address appOwner,
        bytes32 templateHash,
        IInputBox inputBox,
        WithdrawalConfig calldata withdrawalConfig
    ) external override returns (IApplication appContract) {
        appContract = new Application(
            outputsMerkleRootValidator,
            appOwner,
            templateHash,
            inputBox,
            REFUND_OUTPUT_BUILDER,
            SAFE_ERC20_TRANSFER,
            withdrawalConfig
        );

        emit ApplicationCreated(
            outputsMerkleRootValidator,
            appOwner,
            templateHash,
            inputBox,
            withdrawalConfig,
            appContract
        );
    }

    function newApplication(
        IOutputsMerkleRootValidator outputsMerkleRootValidator,
        address appOwner,
        bytes32 templateHash,
        IInputBox inputBox,
        WithdrawalConfig calldata withdrawalConfig,
        bytes32 salt
    ) external override returns (IApplication appContract) {
        appContract = _newApplication(
            outputsMerkleRootValidator,
            appOwner,
            templateHash,
            inputBox,
            withdrawalConfig,
            LibCreate2Salt.permissionless(salt)
        );
    }

    function newReservedApplication(
        IOutputsMerkleRootValidator outputsMerkleRootValidator,
        address appOwner,
        bytes32 templateHash,
        IInputBox inputBox,
        WithdrawalConfig calldata withdrawalConfig,
        bytes32 salt
    ) external override returns (IApplication appContract) {
        appContract = _newApplication(
            outputsMerkleRootValidator,
            appOwner,
            templateHash,
            inputBox,
            withdrawalConfig,
            LibCreate2Salt.reserved(salt, msg.sender)
        );
    }

    function calculateApplicationAddress(
        IOutputsMerkleRootValidator outputsMerkleRootValidator,
        address appOwner,
        bytes32 templateHash,
        IInputBox inputBox,
        WithdrawalConfig calldata withdrawalConfig,
        bytes32 salt
    ) external view override returns (address) {
        return _calculateApplicationAddress(
            outputsMerkleRootValidator,
            appOwner,
            templateHash,
            inputBox,
            withdrawalConfig,
            LibCreate2Salt.permissionless(salt)
        );
    }

    function calculateReservedApplicationAddress(
        IOutputsMerkleRootValidator outputsMerkleRootValidator,
        address appOwner,
        bytes32 templateHash,
        IInputBox inputBox,
        WithdrawalConfig calldata withdrawalConfig,
        bytes32 salt,
        address caller
    ) external view override returns (address) {
        return _calculateApplicationAddress(
            outputsMerkleRootValidator,
            appOwner,
            templateHash,
            inputBox,
            withdrawalConfig,
            LibCreate2Salt.reserved(salt, caller)
        );
    }

    function _newApplication(
        IOutputsMerkleRootValidator outputsMerkleRootValidator,
        address appOwner,
        bytes32 templateHash,
        IInputBox inputBox,
        WithdrawalConfig calldata withdrawalConfig,
        bytes32 salt
    ) internal returns (IApplication appContract) {
        appContract = new Application{salt: salt}(
            outputsMerkleRootValidator,
            appOwner,
            templateHash,
            inputBox,
            REFUND_OUTPUT_BUILDER,
            SAFE_ERC20_TRANSFER,
            withdrawalConfig
        );

        emit ApplicationCreated(
            outputsMerkleRootValidator,
            appOwner,
            templateHash,
            inputBox,
            withdrawalConfig,
            appContract
        );
    }

    function _calculateApplicationAddress(
        IOutputsMerkleRootValidator outputsMerkleRootValidator,
        address appOwner,
        bytes32 templateHash,
        IInputBox inputBox,
        WithdrawalConfig calldata withdrawalConfig,
        bytes32 salt
    ) internal view returns (address) {
        return Create2.computeAddress(
            salt,
            keccak256(
                abi.encodePacked(
                    type(Application).creationCode,
                    abi.encode(
                        outputsMerkleRootValidator,
                        appOwner,
                        templateHash,
                        inputBox,
                        REFUND_OUTPUT_BUILDER,
                        SAFE_ERC20_TRANSFER,
                        withdrawalConfig
                    )
                )
            )
        );
    }
}
