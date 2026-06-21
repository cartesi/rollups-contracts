// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {Create2} from "@openzeppelin-contracts-5.2.0/utils/Create2.sol";

import {RollupsContract} from "../common/RollupsContract.sol";
import {WithdrawalConfig} from "../common/WithdrawalConfig.sol";
import {IOutputsMerkleRootValidator} from "../consensus/IOutputsMerkleRootValidator.sol";
import {IInputBox} from "../inputs/IInputBox.sol";
import {IRefundOutputBuilder} from "../refund/IRefundOutputBuilder.sol";
import {Application} from "./Application.sol";
import {IApplication} from "./IApplication.sol";
import {IApplicationFactory} from "./IApplicationFactory.sol";

/// @title Application Factory
/// @notice Allows anyone to reliably deploy a new `IApplication` contract.
contract ApplicationFactory is IApplicationFactory, RollupsContract {
    IRefundOutputBuilder immutable REFUND_OUTPUT_BUILDER;

    /// @notice Creates an `ApplicationFactory` contract.
    /// @param refundOutputBuilder The refund output builder
    constructor(IRefundOutputBuilder refundOutputBuilder) {
        REFUND_OUTPUT_BUILDER = refundOutputBuilder;
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
        appContract = new Application{salt: salt}(
            outputsMerkleRootValidator,
            appOwner,
            templateHash,
            inputBox,
            REFUND_OUTPUT_BUILDER,
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

    function calculateApplicationAddress(
        IOutputsMerkleRootValidator outputsMerkleRootValidator,
        address appOwner,
        bytes32 templateHash,
        IInputBox inputBox,
        WithdrawalConfig calldata withdrawalConfig,
        bytes32 salt
    ) external view override returns (address) {
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
                        withdrawalConfig
                    )
                )
            )
        );
    }
}
