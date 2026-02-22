// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Application Factory Test
pragma solidity ^0.8.22;

import {WithdrawalConfig} from "src/common/WithdrawalConfig.sol";
import {IOutputsMerkleRootValidator} from "src/consensus/IOutputsMerkleRootValidator.sol";
import {ApplicationFactory} from "src/dapp/ApplicationFactory.sol";
import {IApplication} from "src/dapp/IApplication.sol";
import {IApplicationFactory} from "src/dapp/IApplicationFactory.sol";

import {Ownable} from "@openzeppelin-contracts-5.2.0/access/Ownable.sol";

import {Test} from "forge-std-1.9.6/src/Test.sol";
import {Vm} from "forge-std-1.9.6/src/Vm.sol";

contract ApplicationFactoryTest is Test {
    ApplicationFactory _factory;

    function setUp() external {
        _factory = new ApplicationFactory();
    }

    function testNewApplication(
        uint256 blockNumber,
        IOutputsMerkleRootValidator outputsMerkleRootValidator,
        address appOwner,
        bytes32 templateHash,
        bytes calldata dataAvailability,
        WithdrawalConfig calldata withdrawalConfig
    ) external {
        vm.roll(blockNumber);

        vm.recordLogs();

        try _factory.newApplication(
            outputsMerkleRootValidator,
            appOwner,
            templateHash,
            dataAvailability,
            withdrawalConfig
        ) returns (
            IApplication appContract
        ) {
            Vm.Log[] memory logs = vm.getRecordedLogs();

            _testNewApplicationSuccess(
                outputsMerkleRootValidator,
                appOwner,
                templateHash,
                dataAvailability,
                withdrawalConfig,
                appContract,
                blockNumber,
                logs
            );
        } catch (bytes memory error) {
            _testNewApplicationFailure(appOwner, error);
            return;
        }
    }

    function testNewApplicationDeterministic(
        uint256 blockNumber,
        IOutputsMerkleRootValidator outputsMerkleRootValidator,
        address appOwner,
        bytes32 templateHash,
        bytes calldata dataAvailability,
        WithdrawalConfig calldata withdrawalConfig,
        bytes32 salt
    ) external {
        vm.roll(blockNumber);

        address precalculatedAddress = _factory.calculateApplicationAddress(
            outputsMerkleRootValidator,
            appOwner,
            templateHash,
            dataAvailability,
            withdrawalConfig,
            salt
        );

        vm.recordLogs();

        try _factory.newApplication(
            outputsMerkleRootValidator,
            appOwner,
            templateHash,
            dataAvailability,
            withdrawalConfig,
            salt
        ) returns (
            IApplication appContract
        ) {
            Vm.Log[] memory logs = vm.getRecordedLogs();

            assertEq(
                precalculatedAddress,
                address(appContract),
                "calculateApplicationAddress(...) != newApplication(...)"
            );

            _testNewApplicationSuccess(
                outputsMerkleRootValidator,
                appOwner,
                templateHash,
                dataAvailability,
                withdrawalConfig,
                appContract,
                blockNumber,
                logs
            );
        } catch (bytes memory error) {
            _testNewApplicationFailure(appOwner, error);
            return;
        }

        assertEq(
            _factory.calculateApplicationAddress(
                outputsMerkleRootValidator,
                appOwner,
                templateHash,
                dataAvailability,
                withdrawalConfig,
                salt
            ),
            precalculatedAddress,
            "calculateApplicationAddress(...) is not a pure function"
        );

        // Cannot deploy an application with the same salt twice
        try _factory.newApplication(
            outputsMerkleRootValidator,
            appOwner,
            templateHash,
            dataAvailability,
            withdrawalConfig,
            salt
        ) {
            revert("second deterministic deployment did not revert");
        } catch (bytes memory error) {
            assertEq(
                error,
                new bytes(0),
                "second deterministic deployment did not revert with empty error data"
            );
        }
    }

    function _testNewApplicationSuccess(
        IOutputsMerkleRootValidator outputsMerkleRootValidator,
        address appOwner,
        bytes32 templateHash,
        bytes calldata dataAvailability,
        WithdrawalConfig calldata withdrawalConfig,
        IApplication appContract,
        uint256 blockNumber,
        Vm.Log[] memory logs
    ) internal view {
        uint256 numOfApplicationsCreated;

        for (uint256 i; i < logs.length; ++i) {
            Vm.Log memory log = logs[i];

            if (
                log.emitter == address(_factory)
                    && log.topics[0] == IApplicationFactory.ApplicationCreated.selector
            ) {
                ++numOfApplicationsCreated;

                assertEq(
                    log.topics[1],
                    bytes32(uint256(uint160(address(outputsMerkleRootValidator))))
                );

                (
                    address appOwner_,
                    bytes32 templateHash_,
                    bytes memory dataAvailability_,
                    WithdrawalConfig memory withdrawalConfig_,
                    IApplication app_
                ) = abi.decode(
                    log.data, (address, bytes32, bytes, WithdrawalConfig, IApplication)
                );

                assertEq(appOwner, appOwner_, "ApplicationCreated.owner != owner");
                assertEq(
                    templateHash,
                    templateHash_,
                    "ApplicationCreated.templateHash != templateHash"
                );
                assertEq(
                    dataAvailability,
                    dataAvailability_,
                    "ApplicationCreated.dataAvailability != dataAvailability"
                );
                assertEq(
                    abi.encode(withdrawalConfig),
                    abi.encode(withdrawalConfig_),
                    "ApplicationCreated.withdrawalConfig != withdrawalConfig"
                );
                assertEq(
                    address(appContract),
                    address(app_),
                    "ApplicationCreated.appContract != appContract"
                );
            }
        }

        assertEq(numOfApplicationsCreated, 1, "number of ApplicationCreated events");
        assertEq(
            address(appContract.getOutputsMerkleRootValidator()),
            address(outputsMerkleRootValidator),
            "getOutputsMerkleRootValidator() != outputsMerkleRootValidator"
        );
        assertEq(appContract.owner(), appOwner, "owner() != owner");
        assertEq(
            appContract.getTemplateHash(),
            templateHash,
            "getTemplateHash() != templateHash"
        );
        assertEq(
            appContract.getLog2LeavesPerAccount(),
            withdrawalConfig.log2LeavesPerAccount,
            "getLog2LeavesPerAccount() != withdrawalConfig.log2LeavesPerAccount"
        );
        assertEq(
            appContract.getLog2MaxNumOfAccounts(),
            withdrawalConfig.log2MaxNumOfAccounts,
            "getLog2MaxNumOfAccounts() != withdrawalConfig.log2MaxNumOfAccounts"
        );
        assertEq(
            appContract.getAccountsDriveStartIndex(),
            withdrawalConfig.accountsDriveStartIndex,
            "getAccountsDriveStartIndex() != withdrawalConfig.accountsDriveStartIndex"
        );
        assertEq(
            appContract.getGuardian(),
            withdrawalConfig.guardian,
            "getGuardian() != withdrawalConfig.guardian"
        );
        assertEq(
            address(appContract.getWithdrawer()),
            address(withdrawalConfig.withdrawer),
            "getWithdrawer() != withdrawalConfig.withdrawer"
        );
        assertEq(
            appContract.getDataAvailability(),
            dataAvailability,
            "getDataAvailability() != dataAvailability"
        );
        assertEq(
            appContract.getDeploymentBlockNumber(),
            blockNumber,
            "getDeploymentBlockNumber() != blockNumber"
        );
    }

    function _testNewApplicationFailure(address appOwner, bytes memory error)
        internal
        pure
    {
        assertGe(error.length, 4, "Error data too short (no 4-byte selector)");

        // forge-lint: disable-next-line(unsafe-typecast)
        bytes4 errorSelector = bytes4(error);
        bytes memory errorArgs = new bytes(error.length - 4);

        for (uint256 i; i < errorArgs.length; ++i) {
            errorArgs[i] = error[i + 4];
        }

        if (errorSelector == Ownable.OwnableInvalidOwner.selector) {
            address owner = abi.decode(errorArgs, (address));
            assertEq(owner, appOwner, "OwnableInvalidOwner.owner != owner");
            assertEq(owner, address(0), "OwnableInvalidOwner.owner != address(0)");
        } else {
            revert("Unexpected error");
        }
    }
}
