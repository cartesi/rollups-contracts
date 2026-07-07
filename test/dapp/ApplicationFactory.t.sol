// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Application Factory Test
pragma solidity ^0.8.30;

import {WithdrawalConfig} from "src/common/WithdrawalConfig.sol";
import {IOutputsMerkleRootValidator} from "src/consensus/IOutputsMerkleRootValidator.sol";
import {IApplication} from "src/dapp/IApplication.sol";
import {IApplicationFactory} from "src/dapp/IApplicationFactory.sol";
import {IApplicationFactoryErrors} from "src/dapp/IApplicationFactoryErrors.sol";
import {IInputBox} from "src/inputs/IInputBox.sol";
import {LibWithdrawalConfig} from "src/library/LibWithdrawalConfig.sol";

import {Ownable} from "@openzeppelin-contracts-5.2.0/access/Ownable.sol";

import {Vm} from "forge-std-1.9.6/src/Vm.sol";

import {LibAddressArray} from "../util/LibAddressArray.sol";
import {LibBytes} from "../util/LibBytes.sol";
import {LibTopic} from "../util/LibTopic.sol";
import {OwnableTest} from "../util/OwnableTest.sol";
import {RollupsTest} from "../util/RollupsTest.sol";
import {VersionGetterTestUtils} from "../util/VersionGetterTestUtils.sol";

struct DeploymentArgs {
    bool deterministic;
    IOutputsMerkleRootValidator outputsMerkleRootValidator;
    address appOwner;
    bytes32 templateHash;
    IInputBox inputBox;
    WithdrawalConfig withdrawalConfig;
    bytes32 salt;
}

library LibApplicationFactory {
    function newApplication(
        IApplicationFactory factory,
        DeploymentArgs calldata deploymentArgs
    ) external returns (IApplication) {
        return deploymentArgs.deterministic
            ? factory.newApplication(
                deploymentArgs.outputsMerkleRootValidator,
                deploymentArgs.appOwner,
                deploymentArgs.templateHash,
                deploymentArgs.inputBox,
                deploymentArgs.withdrawalConfig,
                deploymentArgs.salt
            )
            : factory.newApplication(
                deploymentArgs.outputsMerkleRootValidator,
                deploymentArgs.appOwner,
                deploymentArgs.templateHash,
                deploymentArgs.inputBox,
                deploymentArgs.withdrawalConfig
            );
    }

    function calculateApplicationAddress(
        IApplicationFactory factory,
        DeploymentArgs calldata deploymentArgs
    ) external view returns (address) {
        return factory.calculateApplicationAddress(
            deploymentArgs.outputsMerkleRootValidator,
            deploymentArgs.appOwner,
            deploymentArgs.templateHash,
            deploymentArgs.inputBox,
            deploymentArgs.withdrawalConfig,
            deploymentArgs.salt
        );
    }
}

contract ApplicationFactoryTest is RollupsTest, VersionGetterTestUtils, OwnableTest {
    using LibApplicationFactory for IApplicationFactory;
    using LibWithdrawalConfig for WithdrawalConfig;
    using LibAddressArray for Vm;
    using LibTopic for address;
    using LibBytes for bytes;

    IApplicationFactory _factory;

    function setUp() external {
        _factory = _contracts.core.applicationFactory;
    }

    function testVersion() external view {
        _testVersion(_factory);
    }

    function testNewApplication(DeploymentArgs calldata deploymentArgs) external {
        uint256 blockNumber = _randomizeBlockNumber();
        address appContractAddress = _factory.calculateApplicationAddress(deploymentArgs);

        vm.recordLogs();

        try _factory.newApplication(deploymentArgs) returns (IApplication appContract) {
            Vm.Log[] memory logs = vm.getRecordedLogs();

            if (deploymentArgs.deterministic) {
                assertEq(
                    appContractAddress,
                    address(appContract),
                    "calculateApplicationAddress(...) != newApplication(...)"
                );
            }

            uint256 numOfApplicationsCreated;

            for (uint256 i; i < logs.length; ++i) {
                Vm.Log memory log = logs[i];

                if (log.emitter == address(_factory)) {
                    assertGe(log.topics.length, 1);
                    bytes32 topic0 = log.topics[0];
                    if (topic0 == IApplicationFactory.ApplicationCreated.selector) {
                        assertEq(
                            log.topics[1],
                            address(deploymentArgs.outputsMerkleRootValidator).asTopic()
                        );

                        address arg1;
                        bytes32 arg2;
                        address arg3;
                        WithdrawalConfig memory arg4;
                        address arg5;

                        (arg1, arg2, arg3, arg4, arg5) = abi.decode(
                            log.data,
                            (address, bytes32, address, WithdrawalConfig, address)
                        );

                        assertEq(arg1, deploymentArgs.appOwner);
                        assertEq(arg2, deploymentArgs.templateHash);
                        assertEq(arg3, address(deploymentArgs.inputBox));
                        assertEq(arg4, deploymentArgs.withdrawalConfig);
                        assertEq(arg5, address(appContract));

                        ++numOfApplicationsCreated;
                    }
                }
            }

            assertEq(numOfApplicationsCreated, 1, "number of ApplicationCreated events");

            _testVersion(appContract);

            assertEq(
                address(appContract.getOutputsMerkleRootValidator()),
                address(deploymentArgs.outputsMerkleRootValidator),
                "getOutputsMerkleRootValidator() != outputsMerkleRootValidator"
            );
            assertEq(appContract.owner(), deploymentArgs.appOwner, "owner() != owner");
            assertEq(
                appContract.getTemplateHash(),
                deploymentArgs.templateHash,
                "getTemplateHash() != templateHash"
            );
            assertEq(
                abi.encode(appContract.getWithdrawalConfig()),
                abi.encode(deploymentArgs.withdrawalConfig),
                "getWithdrawalConfig() != withdrawalConfig"
            );
            assertEq(
                appContract.getGuardian(),
                deploymentArgs.withdrawalConfig.guardian,
                "getGuardian() != withdrawalConfig.guardian"
            );
            assertEq(
                appContract.getLog2LeavesPerAccount(),
                deploymentArgs.withdrawalConfig.log2LeavesPerAccount,
                "getLog2LeavesPerAccount() != withdrawalConfig.log2LeavesPerAccount"
            );
            assertEq(
                appContract.getLog2MaxNumOfAccounts(),
                deploymentArgs.withdrawalConfig.log2MaxNumOfAccounts,
                "getLog2MaxNumOfAccounts() != withdrawalConfig.log2MaxNumOfAccounts"
            );
            assertEq(
                appContract.getAccountsDriveStartIndex(),
                deploymentArgs.withdrawalConfig.accountsDriveStartIndex,
                "getAccountsDriveStartIndex() != withdrawalConfig.accountsDriveStartIndex"
            );
            assertEq(
                address(appContract.getWithdrawalOutputBuilder()),
                address(deploymentArgs.withdrawalConfig.withdrawalOutputBuilder),
                "getWithdrawalOutputBuilder() != withdrawalConfig.withdrawalOutputBuilder"
            );
            assertEq(
                address(appContract.getInputBox()),
                address(deploymentArgs.inputBox),
                "getInputBox() != inputBox"
            );
            assertEq(
                appContract.getDeploymentBlockNumber(),
                blockNumber,
                "getDeploymentBlockNumber() != blockNumber"
            );
            assertEq(
                appContract.getNumberOfExecutedOutputs(),
                0,
                "getNumberOfExecutedOutputs() != 0"
            );
            assertFalse(
                appContract.wasOutputExecuted(vm.randomUint()),
                "initially, wasOutputExecuted(...) = false"
            );
            assertEq(
                address(appContract.getRefundOutputBuilder()),
                address(_contracts.core.refundOutputBuilder),
                "getRefundOutputBuilder() != RefundOutputBuilder"
            );
            assertEq(
                appContract.getNumberOfIssuedRefunds(),
                0,
                "getNumberOfIssuedRefunds() != 0"
            );
            assertFalse(
                appContract.wasRefundForInputIssued(vm.randomUint()),
                "initially, wasRefundForInputIssued(...) = false"
            );
            assertEq(
                appContract.getNumberOfWithdrawals(), 0, "getNumberOfWithdrawals() != 0"
            );
            assertFalse(
                appContract.wereAccountFundsWithdrawn(vm.randomUint()),
                "initially, wereAccountFundsWithdrawn(...) = false"
            );
            assertEq(
                deploymentArgs.withdrawalConfig.isValid(),
                true,
                "Expected withdrawal config to be valid"
            );
            assertEq(appContract.isForeclosed(), false, "isForeclosed() != false");
            {
                bool wasAccountsDriveMerkleRootProved;
                (wasAccountsDriveMerkleRootProved,) =
                    appContract.getAccountsDriveMerkleRoot();
                assertFalse(
                    wasAccountsDriveMerkleRootProved,
                    "initially, getAccountsDriveMerkleRoot() = (false, _)"
                );
            }

            if (deploymentArgs.deterministic) {
                assertEq(
                    _factory.calculateApplicationAddress(deploymentArgs),
                    appContractAddress,
                    "calculateApplicationAddress(...) is not a pure function"
                );

                // Cannot deploy an application with the same salt twice
                try _factory.newApplication(deploymentArgs) {
                    revert("second deterministic deployment did not revert");
                } catch (bytes memory errorData) {
                    assertEq(
                        errorData,
                        new bytes(0),
                        "second deterministic deployment did not revert with empty error data"
                    );
                }
            }
        } catch (bytes memory errorData) {
            (bytes4 errorSelector, bytes memory errorArgs) = errorData.consumeBytes4();
            if (errorSelector == Ownable.OwnableInvalidOwner.selector) {
                address owner = abi.decode(errorArgs, (address));
                assertEq(
                    owner,
                    deploymentArgs.appOwner,
                    "OwnableInvalidOwner.owner != appOwner"
                );
                assertEq(owner, address(0), "OwnableInvalidOwner.owner != address(0)");
            } else if (
                errorSelector
                    == IApplicationFactoryErrors.InvalidWithdrawalConfig.selector
            ) {
                assertEq(
                    errorArgs,
                    abi.encode(deploymentArgs.withdrawalConfig),
                    "InvalidWithdrawalConfig.withdrawalConfig != withdrawalConfig"
                );
                assertFalse(
                    deploymentArgs.withdrawalConfig.isValid(),
                    "expected withdrawal config to be invalid"
                );
            }
        }
    }

    function testMigrateToOutputsMerkleRootValidator(
        DeploymentArgs calldata deploymentArgs,
        IOutputsMerkleRootValidator[] calldata omrvs
    ) external {
        uint256 blockNumber = _randomizeBlockNumber();
        IApplication appContract = _newApplication(deploymentArgs);

        for (uint256 i = 1; i < omrvs.length; ++i) {
            IOutputsMerkleRootValidator omrv = omrvs[i];

            vm.prank(appContract.owner());
            vm.recordLogs();
            appContract.migrateToOutputsMerkleRootValidator(omrv);

            Vm.Log[] memory logs = vm.getRecordedLogs();

            for (uint256 j; j < logs.length; ++j) {
                Vm.Log memory log = logs[j];
                if (log.emitter == address(appContract)) {
                    assertGe(log.topics.length, 1);
                    bytes32 topic0 = log.topics[0];
                    if (topic0 == IApplication.OutputsMerkleRootValidatorChanged.selector)
                    {
                        assertEq(log.topics.length, 1);
                        assertEq(log.data, abi.encode(omrv));
                    } else {
                        revert("unexpected log topic #0");
                    }
                } else {
                    revert("unexpected log emitter");
                }
            }

            assertEq(address(appContract.getOutputsMerkleRootValidator()), address(omrv));
        }

        if (omrvs.length >= 1) {
            IOutputsMerkleRootValidator omrv = omrvs[0];

            vm.expectRevert(IApplication.Foreclosed.selector);
            this.simulateForeclosureAndMigration(appContract, omrv);

            if (blockNumber <= type(uint256).max - 1) {
                vm.expectRevert(IApplication.NotDeploymentBlock.selector);
                this.simulateRollingAndMigration(appContract, blockNumber + 1, omrv);
            }

            {
                address[] memory authorizedAccounts = new address[](1);
                authorizedAccounts[0] = appContract.owner();

                address unauthorizedAccount = vm.randomAddressNotIn(authorizedAccounts);
                vm.prank(unauthorizedAccount);
                vm.expectRevert(_encodeOwnableUnauthorizedAccount(unauthorizedAccount));
                appContract.migrateToOutputsMerkleRootValidator(omrv);
            }
        }
    }

    /// @notice This function is used to simulate rolling past a certain block and making a migration.
    /// If the migration succeeds, then the function reverts with error message "Successful migration".
    /// If the migration fails, then the function propagates the error from the app contract.
    function simulateRollingAndMigration(
        IApplication appContract,
        uint256 minBlockNumber,
        IOutputsMerkleRootValidator omrv
    ) external {
        vm.roll(minBlockNumber);
        _randomizeBlockNumber();
        vm.prank(appContract.owner());
        appContract.migrateToOutputsMerkleRootValidator(omrv);
        revert("Successful migration");
    }

    /// @notice This function is used to simulate an app foreclosure followed by a consensus migration.
    /// If the migration succeeds, then the function reverts with error message "Successful migration".
    /// If the migration fails, then the function propagates the error from the app contract.
    function simulateForeclosureAndMigration(
        IApplication appContract,
        IOutputsMerkleRootValidator omrv
    ) external {
        vm.prank(appContract.getGuardian());
        appContract.foreclose();
        vm.prank(appContract.owner());
        appContract.migrateToOutputsMerkleRootValidator(omrv);
        revert("Successful migration");
    }

    function assertEq(WithdrawalConfig memory wc1, WithdrawalConfig memory wc2)
        internal
        pure
    {
        assertEq(abi.encode(wc1), abi.encode(wc2));
    }

    function _randomizeBlockNumber() internal returns (uint256 blockNumber) {
        blockNumber = vm.randomUint(vm.getBlockNumber(), type(uint256).max);
        vm.roll(blockNumber);
    }

    function _newApplication(DeploymentArgs calldata deploymentArgs)
        internal
        returns (IApplication)
    {
        vm.assumeNoRevert();
        return _factory.newApplication(deploymentArgs);
    }
}
