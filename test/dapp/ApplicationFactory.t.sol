// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Application Factory Test
pragma solidity ^0.8.30;

import {CanonicalMachine} from "../../src/common/CanonicalMachine.sol";
import {WithdrawalConfig} from "../../src/common/WithdrawalConfig.sol";
import {IOutputsMerkleRootValidator} from "../../src/consensus/IOutputsMerkleRootValidator.sol";
import {IApplication} from "../../src/dapp/IApplication.sol";
import {IApplicationFactory} from "../../src/dapp/IApplicationFactory.sol";
import {IApplicationFactoryErrors} from "../../src/dapp/IApplicationFactoryErrors.sol";
import {IInputBox} from "../../src/inputs/IInputBox.sol";
import {LibWithdrawalConfig} from "../../src/library/LibWithdrawalConfig.sol";

import {Ownable} from "@openzeppelin-contracts-5.2.0/access/Ownable.sol";

import {Vm} from "forge-std-1.9.6/src/Vm.sol";

import {ConsensusTestUtils} from "../util/ConsensusTestUtils.sol";
import {LibAddressArray} from "../util/LibAddressArray.sol";
import {LibBinaryKeccak256MerkleTree} from "../util/LibBinaryKeccak256MerkleTree.sol";
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

contract ApplicationFactoryTest is
    RollupsTest,
    VersionGetterTestUtils,
    OwnableTest,
    ConsensusTestUtils
{
    using LibApplicationFactory for IApplicationFactory;
    using LibBinaryKeccak256MerkleTree for bytes32[];
    using LibWithdrawalConfig for WithdrawalConfig;
    using LibAddressArray for Vm;
    using LibTopic for address;
    using LibBytes for bytes;

    IApplicationFactory _factory;

    function setUp() external {
        _factory = _contracts.core.applicationFactory;
    }

    // -------
    // version
    // -------

    function testVersion() external view {
        _testVersion(_factory);
    }

    // ----------
    // deployment
    // ----------

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
            uint256 numOfOwnershipTransferred;

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
                    } else {
                        revert UnexpectedLog(log);
                    }
                } else if (log.emitter == address(appContract)) {
                    assertGe(log.topics.length, 1);
                    bytes32 topic0 = log.topics[0];
                    if (topic0 == Ownable.OwnershipTransferred.selector) {
                        assertEq(log.topics[1], address(0).asTopic());
                        assertEq(log.topics[2], deploymentArgs.appOwner.asTopic());

                        ++numOfOwnershipTransferred;
                    }
                } else {
                    revert UnexpectedLog(log);
                }
            }

            assertEq(numOfApplicationsCreated, 1, "number of ApplicationCreated events");
            assertEq(
                numOfOwnershipTransferred, 1, "number of OwnershipTransferred events"
            );

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

    // ---------------------------------------
    // outputs Merkle root validator migration
    // ---------------------------------------

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
                        revert UnexpectedLog(log);
                    }
                } else {
                    revert UnexpectedLog(log);
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

    // ------------
    // ownable test
    // ------------

    function testRenounceOwnership(DeploymentArgs calldata deploymentArgs) external {
        _testRenounceOwnership(_newApplication(deploymentArgs));
    }

    function testUnauthorizedAccount(DeploymentArgs calldata deploymentArgs) external {
        _testUnauthorizedAccount(_newApplication(deploymentArgs));
    }

    function testInvalidOwner(DeploymentArgs calldata deploymentArgs) external {
        _testInvalidOwner(_newApplication(deploymentArgs));
    }

    function testTransferOwnership(DeploymentArgs calldata deploymentArgs) external {
        _testTransferOwnership(_newApplication(deploymentArgs));
    }

    // -----------
    // foreclosure
    // -----------

    function testForecloseRevertsNotGuardian(
        DeploymentArgs calldata deploymentArgs,
        address caller
    ) external {
        IApplication appContract = _newApplication(deploymentArgs);
        vm.assume(caller != appContract.getGuardian());
        vm.expectRevert(IApplication.NotGuardian.selector);
        vm.prank(caller);
        appContract.foreclose();
    }

    function testForeclose(DeploymentArgs calldata deploymentArgs, address caller)
        external
    {
        IApplication appContract = _newApplication(deploymentArgs);
        address guardian = appContract.getGuardian();
        vm.assume(caller != guardian);

        vm.recordLogs();

        vm.prank(guardian);
        appContract.foreclose();

        Vm.Log[] memory logs = vm.getRecordedLogs();

        uint256 numOfForeclosureEvents;

        for (uint256 i; i < logs.length; ++i) {
            Vm.Log memory log = logs[i];
            if (log.emitter == address(appContract)) {
                require(log.topics.length >= 1, UnexpectedLog(log));
                bytes32 topic0 = log.topics[0];
                if (topic0 == IApplication.Foreclosure.selector) {
                    assertEq(log.topics.length, 1);
                    assertEq(log.data, abi.encode());
                    ++numOfForeclosureEvents;
                } else {
                    revert UnexpectedLog(log);
                }
            } else {
                revert UnexpectedLog(log);
            }
        }

        assertEq(numOfForeclosureEvents, 1);
        assertTrue(appContract.isForeclosed());

        vm.expectRevert(IApplication.Foreclosed.selector);
        vm.prank(guardian);
        appContract.foreclose();

        vm.expectRevert(IApplication.NotGuardian.selector);
        vm.prank(caller);
        appContract.foreclose();
    }

    // ----------------------------------
    // accounts drive Merkle root proving
    // ----------------------------------

    function testRevertsInvalidAccountsDriveMerkleRootProofSize(
        DeploymentArgs calldata deploymentArgs,
        bytes32 lastFinalizedMachineMerkleRoot,
        bytes32 accountsDriveMerkleRoot,
        bytes32[] calldata invalidProof
    ) external {
        IApplication appContract = _newApplication(deploymentArgs);

        // We assume the proof provided by the fuzzer has an invalid size,
        // according to the application withdrawal config, which are assumed
        // to be valid given that we were able to deploy the application.
        vm.assume(
            invalidProof.length != _getAccountsDriveMerkleRootProofSize(deploymentArgs)
        );

        // We make the outputs Merkle root validator return the fuzzed
        // last-finalized machine Merkle root. If zero, the application
        // contract uses the template hash instead.
        _mockGetLastFinalizedMachineMerkleRoot(
            deploymentArgs.outputsMerkleRootValidator,
            appContract,
            lastFinalizedMachineMerkleRoot
        );

        // Randomize the foreclosure block number.
        _randomizeBlockNumber();

        // We foreclose the application so that we can prove
        // the accounts drive Merkle root.
        vm.prank(appContract.getGuardian());
        appContract.foreclose();

        // Randomize the proof block number.
        _randomizeBlockNumber();

        // We attempt to prove the accounts drive Merkle root
        // with a Merkle proof of invalid size.
        vm.expectRevert(IApplication.InvalidAccountsDriveMerkleRootProofSize.selector);
        vm.prank(vm.randomAddress());
        appContract.proveAccountsDriveMerkleRoot(accountsDriveMerkleRoot, invalidProof);
    }

    function testRevertsInvalidMachineMerkleRoot(
        DeploymentArgs calldata deploymentArgs,
        bytes32 invalidAccountsDriveMerkleRoot,
        bytes32 lastFinalizedMachineMerkleRoot
    ) external {
        IApplication appContract = _newApplication(deploymentArgs);

        // Generate a random Merkle proof with the correct size for
        // the accounts drive Merkle root, given the withdrawal config
        // of the application.
        bytes32[] memory proof =
            _randomBytes32Array(_getAccountsDriveMerkleRootProofSize(deploymentArgs));

        // Compute the machine Merkle root from the random Merkle proof and
        // accounts drive Merkle root, so that we can be sure that it differs
        // from the actual last-finalized machine Merkle root.
        bytes32 invalidMachineMerkleRoot = proof.merkleRootAfterReplacement(
            deploymentArgs.withdrawalConfig.accountsDriveStartIndex,
            invalidAccountsDriveMerkleRoot
        );

        // Ensure that the machine Merkle root proved from the random proof
        // differs from the last-finalized machine Merkle root or (if zero)
        // from the application template hash.
        vm.assume(
            invalidMachineMerkleRoot
                != ((lastFinalizedMachineMerkleRoot == bytes32(0))
                        ? deploymentArgs.templateHash
                        : lastFinalizedMachineMerkleRoot)
        );

        // We make the outputs Merkle root validator return the fuzzed
        // last-finalized machine Merkle root. If zero, the application
        // contract uses the template hash instead.
        _mockGetLastFinalizedMachineMerkleRoot(
            deploymentArgs.outputsMerkleRootValidator,
            appContract,
            lastFinalizedMachineMerkleRoot
        );

        // Randomize the foreclosure block number.
        _randomizeBlockNumber();

        // We foreclose the application so that we can prove
        // the accounts drive Merkle root.
        vm.prank(appContract.getGuardian());
        appContract.foreclose();

        // Randomize the proof block number.
        _randomizeBlockNumber();

        // We attempt to prove a different accounts drive Merkle root.
        vm.expectRevert(_encodeInvalidMachineMerkleRoot(invalidMachineMerkleRoot));
        vm.prank(vm.randomAddress());
        appContract.proveAccountsDriveMerkleRoot(invalidAccountsDriveMerkleRoot, proof);
    }

    function testProveAccountsDriveMerkleRoot(
        DeploymentArgs memory deploymentArgs,
        bytes32 accountsDriveMerkleRoot
    ) external {
        // We first need to assume that the withdrawal config is valid,
        // in order to compute the accounts drive Merkle root.
        // If the withdrawal config is not valid, the application contract
        // wouldn't be deployed anyway, so this adds no extra restriction.
        vm.assume(deploymentArgs.withdrawalConfig.isValid());

        // Generate a random Merkle proof with the correct size for
        // the accounts drive Merkle root, given the withdrawal config
        // of the application.
        bytes32[] memory proof =
            _randomBytes32Array(_getAccountsDriveMerkleRootProofSize(deploymentArgs));

        // Compute the machine Merkle root from the random Merkle proof and
        // accounts drive Merkle root, so that we later prove it bottom-up.
        bytes32 machineMerkleRoot = proof.merkleRootAfterReplacement(
            deploymentArgs.withdrawalConfig.accountsDriveStartIndex,
            accountsDriveMerkleRoot
        );

        // At random, we choose to prove the accounts drive Merkle root
        // from the template hash or from the last-finalized machine Merkle
        // root provided by the outputs Merkle root validator.
        bool proveFromTemplate = vm.randomBool();

        // If proving from the template hash, we use the computed machine
        // Merkle root as the template hash of the application.
        if (proveFromTemplate) {
            deploymentArgs.templateHash = machineMerkleRoot;
        }

        // We deploy the application which may have the computed machine Merkle root
        // as template hash depending on the previous step.
        IApplication appContract = _newApplication(deploymentArgs);

        // We mock the getLastFinalizedMachineMerkleRoot to return zero if proving
        // from the template hash, or the computed machine Merkle root otherwise.
        _mockGetLastFinalizedMachineMerkleRoot(
            deploymentArgs.outputsMerkleRootValidator,
            appContract,
            proveFromTemplate ? bytes32(0) : machineMerkleRoot
        );

        // Randomize the proof attempt and foreclosure block number.
        _randomizeBlockNumber();

        // Attempt to prove the accounts drive Merkle root before
        // the guardian has foreclosed the application.
        vm.expectRevert(IApplication.NotForeclosed.selector);
        vm.prank(vm.randomAddress());
        appContract.proveAccountsDriveMerkleRoot(accountsDriveMerkleRoot, proof);

        // Make the guardian foreclose the application.
        vm.prank(appContract.getGuardian());
        appContract.foreclose();

        // The accounts drive Merkle root should still be unproved.
        // That is, getAccountsDriveMerkleRoot() should return (false, _).
        {
            bool wasValueProved;
            (wasValueProved,) = appContract.getAccountsDriveMerkleRoot();
            assertFalse(wasValueProved);
        }

        // Randomize the proof block number.
        _randomizeBlockNumber();

        // Prove the accounts drive Merkle root.
        vm.recordLogs();
        vm.prank(vm.randomAddress());
        appContract.proveAccountsDriveMerkleRoot(accountsDriveMerkleRoot, proof);

        // Ensure the AccountsDriveMerkleRootProved event was emitted.
        {
            Vm.Log[] memory logs = vm.getRecordedLogs();
            uint256 numOfAccountsDriveMerkleRootProvedEvents;
            for (uint256 i; i < logs.length; ++i) {
                Vm.Log memory log = logs[i];
                if (log.emitter == address(appContract)) {
                    assertGe(log.topics.length, 1);
                    bytes32 topic0 = log.topics[0];
                    if (topic0 == IApplication.AccountsDriveMerkleRootProved.selector) {
                        bytes32 arg1 = abi.decode(log.data, (bytes32));
                        assertEq(arg1, accountsDriveMerkleRoot);
                        ++numOfAccountsDriveMerkleRootProvedEvents;
                    } else {
                        revert UnexpectedLog(log);
                    }
                } else {
                    revert UnexpectedLog(log);
                }
            }
            assertEq(numOfAccountsDriveMerkleRootProvedEvents, 1);
        }

        // The accounts drive Merkle root should now be marked as proved.
        // That is, getAccountsDriveMerkleRoot() should return (true, x)
        // where x is the accounts drive Merkle root that was proved.
        {
            bool wasValueProved;
            bytes32 value;
            (wasValueProved, value) = appContract.getAccountsDriveMerkleRoot();
            assertTrue(wasValueProved);
            assertEq(value, accountsDriveMerkleRoot);
        }

        // Randomize the second proof attempt block number.
        _randomizeBlockNumber();

        // Attempting to prove the same accounts drive Merkle root fails.
        vm.expectRevert(IApplication.AccountsDriveMerkleRootAlreadyProved.selector);
        vm.prank(vm.randomAddress());
        appContract.proveAccountsDriveMerkleRoot(accountsDriveMerkleRoot, proof);

        // If the outputs Merkle root validator (for some reason) returns a
        // different last-finalized machine Merkle root even after foreclosure,
        // it will still be impossible to prove a different accounts drive Merkle root.
        // Since we cannot change the template hash, we generate another random
        // machine Merkle root, and make the outputs Merkle root validator return it.
        // To do so, we need to first clear the mocked calls.
        {
            accountsDriveMerkleRoot = bytes32(vm.randomUint());
            proof = _randomBytes32Array(proof.length);
            vm.clearMockedCalls();
            _mockGetLastFinalizedMachineMerkleRoot(
                deploymentArgs.outputsMerkleRootValidator,
                appContract,
                proof.merkleRootAfterReplacement(
                    deploymentArgs.withdrawalConfig.accountsDriveStartIndex,
                    accountsDriveMerkleRoot
                )
            );
            vm.expectRevert(IApplication.AccountsDriveMerkleRootAlreadyProved.selector);
            vm.prank(vm.randomAddress());
            appContract.proveAccountsDriveMerkleRoot(accountsDriveMerkleRoot, proof);
        }
    }

    // -----------
    // simulations
    // -----------

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

    // ------------------
    // internal functions
    // ------------------

    function _encodeInvalidMachineMerkleRoot(bytes32 machineMerkleRoot)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IApplication.InvalidMachineMerkleRoot.selector, machineMerkleRoot
        );
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

    function _newApplication(DeploymentArgs memory deploymentArgs)
        internal
        returns (IApplication)
    {
        vm.assumeNoRevert();
        return _factory.newApplication(deploymentArgs);
    }

    function _getAccountsDriveMerkleRootProofSize(DeploymentArgs memory deploymentArgs)
        internal
        pure
        returns (uint256)
    {
        return CanonicalMachine.LOG2_MEMORY_SIZE - CanonicalMachine.LOG2_DATA_BLOCK_SIZE
            - deploymentArgs.withdrawalConfig.log2MaxNumOfAccounts
            - deploymentArgs.withdrawalConfig.log2LeavesPerAccount;
    }

    function _mockGetLastFinalizedMachineMerkleRoot(
        IOutputsMerkleRootValidator outputsMerkleRootValidator,
        IApplication appContract,
        bytes32 lastFinalizedMachineMerkleRoot
    ) internal {
        vm.mockCall(
            address(outputsMerkleRootValidator),
            abi.encodeCall(
                IOutputsMerkleRootValidator.getLastFinalizedMachineMerkleRoot,
                (address(appContract))
            ),
            abi.encode(lastFinalizedMachineMerkleRoot)
        );
    }
}
