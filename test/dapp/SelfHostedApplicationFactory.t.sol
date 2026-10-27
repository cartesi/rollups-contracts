// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Self-hosted Application Factory Test
pragma solidity ^0.8.30;

import {Ownable} from "@openzeppelin-contracts-5.2.0/access/Ownable.sol";

import {WithdrawalConfig} from "../../src/common/WithdrawalConfig.sol";
import {IConsensusFactoryErrors} from "../../src/consensus/IConsensusFactoryErrors.sol";
import {IOutputsMerkleRootValidator} from "../../src/consensus/IOutputsMerkleRootValidator.sol";
import {IAuthority} from "../../src/consensus/authority/IAuthority.sol";
import {IAuthorityFactory} from "../../src/consensus/authority/IAuthorityFactory.sol";
import {IApplication} from "../../src/dapp/IApplication.sol";
import {IApplicationFactory} from "../../src/dapp/IApplicationFactory.sol";
import {IApplicationFactoryErrors} from "../../src/dapp/IApplicationFactoryErrors.sol";
import {ISelfHostedApplicationFactory} from "../../src/dapp/ISelfHostedApplicationFactory.sol";
import {IInputBox} from "../../src/inputs/IInputBox.sol";
import {LibWithdrawalConfig} from "../../src/library/LibWithdrawalConfig.sol";

import {LibBytes} from "../util/LibBytes.sol";
import {RollupsTest} from "../util/RollupsTest.sol";
import {VersionGetterTestUtils} from "../util/VersionGetterTestUtils.sol";
import {WithdrawalConfigTestUtils} from "../util/WithdrawalConfigTestUtils.sol";

struct DeploymentArgs {
    address authorityOwner;
    uint256 epochLength;
    uint256 claimStagingPeriod;
    bytes32 templateHash;
    IInputBox inputBox;
    WithdrawalConfig withdrawalConfig;
    bytes32 salt;
}

library LibSelfHostedApplicationFactory {
    function deployContracts(
        ISelfHostedApplicationFactory factory,
        DeploymentArgs calldata deploymentArgs
    ) external returns (IApplication, IAuthority) {
        return _deployContracts(factory, deploymentArgs);
    }

    function _deployContracts(
        ISelfHostedApplicationFactory factory,
        DeploymentArgs memory deploymentArgs
    ) internal returns (IApplication, IAuthority) {
        return factory.deployContracts(
            deploymentArgs.authorityOwner,
            deploymentArgs.epochLength,
            deploymentArgs.claimStagingPeriod,
            deploymentArgs.templateHash,
            deploymentArgs.inputBox,
            deploymentArgs.withdrawalConfig,
            deploymentArgs.salt
        );
    }

    function _calculateAddresses(
        ISelfHostedApplicationFactory factory,
        DeploymentArgs memory deploymentArgs
    ) internal view returns (address, address) {
        return factory.calculateAddresses(
            deploymentArgs.authorityOwner,
            deploymentArgs.epochLength,
            deploymentArgs.claimStagingPeriod,
            deploymentArgs.templateHash,
            deploymentArgs.inputBox,
            deploymentArgs.withdrawalConfig,
            deploymentArgs.salt
        );
    }
}

contract SelfHostedApplicationFactoryTest is
    RollupsTest,
    VersionGetterTestUtils,
    WithdrawalConfigTestUtils
{
    using LibSelfHostedApplicationFactory for ISelfHostedApplicationFactory;
    using LibWithdrawalConfig for WithdrawalConfig;
    using LibBytes for bytes;

    IAuthorityFactory _authorityFactory;
    IApplicationFactory _applicationFactory;
    ISelfHostedApplicationFactory _factory;

    function setUp() external {
        _authorityFactory = _contracts.core.authorityFactory;
        _applicationFactory = _contracts.core.applicationFactory;
        _factory = _contracts.core.selfHostedApplicationFactory;
    }

    function testVersion() external view {
        _testVersion(_factory);
    }

    function testGetApplicationContract() external view {
        assertEq(address(_factory.getApplicationFactory()), address(_applicationFactory));
    }

    function testGetAuthorityFactory() external view {
        assertEq(address(_factory.getAuthorityFactory()), address(_authorityFactory));
    }

    function testDeployContracts(
        uint256 blockNumber,
        DeploymentArgs calldata deploymentArgs
    ) external {
        _testDeployContracts(blockNumber, deploymentArgs);
    }

    function testDeployContractsWithValidDeploymentArgs(
        uint256 blockNumber,
        DeploymentArgs memory deploymentArgs
    ) external {
        _makeDeploymentArgsValidInPlace(deploymentArgs);
        _testDeployContracts(blockNumber, deploymentArgs);
    }

    function _testDeployContracts(
        uint256 blockNumber,
        DeploymentArgs memory deploymentArgs
    ) internal {
        vm.roll(blockNumber);

        address appAddr;
        address authorityAddr;

        (appAddr, authorityAddr) = _factory._calculateAddresses(deploymentArgs);

        try _factory.deployContracts(deploymentArgs) returns (
            IApplication application, IAuthority authority
        ) {
            _testVersion(application);
            _testVersion(authority);

            assertEq(
                appAddr,
                address(application),
                "calculateAddresses(...)[0] != deployContracts(...)[0]"
            );
            assertEq(
                authorityAddr,
                address(authority),
                "calculateAddresses(...)[1] != deployContracts(...)[1]"
            );

            assertEq(
                authority.owner(),
                deploymentArgs.authorityOwner,
                "authority.owner() != authorityOwner"
            );
            assertEq(
                authority.getEpochLength(),
                deploymentArgs.epochLength,
                "authority.getEpochLength() != epochLength"
            );
            assertGt(deploymentArgs.epochLength, 0, "getEpochLength() > 0");
            assertEq(
                authority.getClaimStagingPeriod(),
                deploymentArgs.claimStagingPeriod,
                "authority.getClaimStagingPeriod() == claimStagingPeriod"
            );

            assertEq(
                address(application.getOutputsMerkleRootValidator()),
                authorityAddr,
                "app.getOutputsMerkleRootValidator() != authority"
            );
            assertEq(application.owner(), address(0), "app.owner() == address(0)");
            assertEq(
                application.getTemplateHash(),
                deploymentArgs.templateHash,
                "app.getTemplateHash() != templateHash"
            );
            assertEq(
                abi.encode(application.getWithdrawalConfig()),
                abi.encode(deploymentArgs.withdrawalConfig),
                "app.getWithdrawalConfig() != withdrawalConfig"
            );
            assertEq(
                application.getGuardian(),
                deploymentArgs.withdrawalConfig.guardian,
                "app.getGuardian() != withdrawalConfig.guardian"
            );
            assertEq(
                application.getLog2LeavesPerAccount(),
                deploymentArgs.withdrawalConfig.log2LeavesPerAccount,
                "app.getLog2LeavesPerAccount() != withdrawalConfig.log2LeavesPerAccount"
            );
            assertEq(
                application.getLog2MaxNumOfAccounts(),
                deploymentArgs.withdrawalConfig.log2MaxNumOfAccounts,
                "app.getLog2MaxNumOfAccounts() != withdrawalConfig.log2MaxNumOfAccounts"
            );
            assertEq(
                application.getAccountsDriveStartIndex(),
                deploymentArgs.withdrawalConfig.accountsDriveStartIndex,
                "app.getAccountsDriveStartIndex() != withdrawalConfig.accountsDriveStartIndex"
            );
            assertEq(
                address(application.getWithdrawalOutputBuilder()),
                address(deploymentArgs.withdrawalConfig.withdrawalOutputBuilder),
                "app.getWithdrawalOutputBuilder() != withdrawalConfig.withdrawalOutputBuilder"
            );
            assertEq(
                address(application.getInputBox()),
                address(deploymentArgs.inputBox),
                "app.getInputBox() != inputBox"
            );
            assertEq(
                application.getDeploymentBlockNumber(),
                blockNumber,
                "getDeploymentBlockNumber() != blockNumber"
            );
            assertTrue(
                deploymentArgs.withdrawalConfig.isValid(), "Invalid withdrawal config"
            );
            assertFalse(application.isForeclosed(), "isForeclosed() != false");

            (appAddr, authorityAddr) = _factory._calculateAddresses(deploymentArgs);

            assertEq(
                appAddr,
                address(application),
                "calculateAddresses(...) is not a pure function"
            );
            assertEq(
                authorityAddr,
                address(authority),
                "calculateAddresses(...) is not a pure function"
            );

            try _factory.deployContracts(deploymentArgs) {
                revert("second deployment did not revert");
            } catch (bytes memory errorData) {
                assertEq(
                    errorData,
                    new bytes(0),
                    "second deployment did not revert with empty error data"
                );
            }
        } catch (bytes memory errorData) {
            (bytes4 errorSelector, bytes memory errorArgs) = errorData.consumeBytes4();
            if (errorSelector == Ownable.OwnableInvalidOwner.selector) {
                address owner = abi.decode(errorArgs, (address));
                assertEq(owner, address(0), "OwnableInvalidOwner.owner != address(0)");
                assertEq(
                    deploymentArgs.authorityOwner,
                    address(0),
                    "authorityOwner != address(0)"
                );
            } else if (errorSelector == IConsensusFactoryErrors.ZeroEpochLength.selector)
            {
                assertEq(errorArgs.length, 0, "expected ZeroEpochLength to have no args");
                assertEq(deploymentArgs.epochLength, 0, "epochLength != 0");
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
            } else {
                revert UnexpectedError(errorData);
            }
        }
    }

    function testDeployContractsSurvivesPartialFrontRunWithOtherAuthorityOwner(
        DeploymentArgs calldata deploymentArgs,
        address otherAuthorityOwner,
        address frontRunner
    ) external {
        DeploymentArgs memory frontRunDeploymentArgs = deploymentArgs;
        frontRunDeploymentArgs.authorityOwner = otherAuthorityOwner;
        _testDeployContractsSurvivesPartialFrontRun(
            deploymentArgs, frontRunDeploymentArgs, frontRunner
        );
    }

    function testDeployContractsSurvivesPartialFrontRunWithOtherEpochLength(
        DeploymentArgs calldata deploymentArgs,
        uint256 otherEpochLength,
        address frontRunner
    ) external {
        DeploymentArgs memory frontRunDeploymentArgs = deploymentArgs;
        frontRunDeploymentArgs.epochLength = otherEpochLength;
        _testDeployContractsSurvivesPartialFrontRun(
            deploymentArgs, frontRunDeploymentArgs, frontRunner
        );
    }

    function testDeployContractsSurvivesPartialFrontRunWithOtherClaimStagingPeriod(
        DeploymentArgs calldata deploymentArgs,
        uint256 otherClaimStagingPeriod,
        address frontRunner
    ) external {
        DeploymentArgs memory frontRunDeploymentArgs = deploymentArgs;
        frontRunDeploymentArgs.claimStagingPeriod = otherClaimStagingPeriod;
        _testDeployContractsSurvivesPartialFrontRun(
            deploymentArgs, frontRunDeploymentArgs, frontRunner
        );
    }

    function testDeployContractsSurvivesPartialFrontRunWithOtherTemplateHash(
        DeploymentArgs calldata deploymentArgs,
        bytes32 otherTemplateHash,
        address frontRunner
    ) external {
        DeploymentArgs memory frontRunDeploymentArgs = deploymentArgs;
        frontRunDeploymentArgs.templateHash = otherTemplateHash;
        _testDeployContractsSurvivesPartialFrontRun(
            deploymentArgs, frontRunDeploymentArgs, frontRunner
        );
    }

    function testDeployContractsSurvivesPartialFrontRunWithOtherInputBox(
        DeploymentArgs calldata deploymentArgs,
        IInputBox otherInputBox,
        address frontRunner
    ) external {
        DeploymentArgs memory frontRunDeploymentArgs = deploymentArgs;
        frontRunDeploymentArgs.inputBox = otherInputBox;
        _testDeployContractsSurvivesPartialFrontRun(
            deploymentArgs, frontRunDeploymentArgs, frontRunner
        );
    }

    function testDeployContractsSurvivesPartialFrontRunWithOtherWithdrawalConfig(
        DeploymentArgs calldata deploymentArgs,
        WithdrawalConfig calldata otherWithdrawalConfig,
        address frontRunner
    ) external {
        DeploymentArgs memory frontRunDeploymentArgs = deploymentArgs;
        frontRunDeploymentArgs.withdrawalConfig = otherWithdrawalConfig;
        _testDeployContractsSurvivesPartialFrontRun(
            deploymentArgs, frontRunDeploymentArgs, frontRunner
        );
    }

    function testDeployContractsSurvivesPartialFrontRunWithOtherSalt(
        DeploymentArgs calldata deploymentArgs,
        bytes32 otherSalt,
        address frontRunner
    ) external {
        DeploymentArgs memory frontRunDeploymentArgs = deploymentArgs;
        frontRunDeploymentArgs.salt = otherSalt;
        _testDeployContractsSurvivesPartialFrontRun(
            deploymentArgs, frontRunDeploymentArgs, frontRunner
        );
    }

    function testDeployContractsSurvivesUnderlyingFactoriesFrontRun(
        DeploymentArgs memory deploymentArgs,
        address frontRunner
    ) external {
        vm.assume(frontRunner != address(_factory));
        _makeDeploymentArgsValidInPlace(deploymentArgs);

        (address appAddr, address authorityAddr) =
            _factory._calculateAddresses(deploymentArgs);

        // A third party deploys through the underlying factories directly,
        // with the same arguments and salt, through every deterministic path.
        // Neither contract lands at the self-hosted addresses.
        vm.startPrank(frontRunner);
        IAuthority frontRunAuthority = _authorityFactory.newAuthority(
            deploymentArgs.authorityOwner,
            deploymentArgs.epochLength,
            deploymentArgs.claimStagingPeriod,
            deploymentArgs.salt
        );
        assertNotEq(address(frontRunAuthority), authorityAddr);
        frontRunAuthority = _authorityFactory.newReservedAuthority(
            deploymentArgs.authorityOwner,
            deploymentArgs.epochLength,
            deploymentArgs.claimStagingPeriod,
            deploymentArgs.salt
        );
        assertNotEq(address(frontRunAuthority), authorityAddr);
        IApplication frontRunApp = _applicationFactory.newApplication(
            IOutputsMerkleRootValidator(authorityAddr),
            address(_factory),
            deploymentArgs.templateHash,
            deploymentArgs.inputBox,
            deploymentArgs.withdrawalConfig,
            deploymentArgs.salt
        );
        assertNotEq(address(frontRunApp), appAddr);
        frontRunApp = _applicationFactory.newReservedApplication(
            IOutputsMerkleRootValidator(authorityAddr),
            address(_factory),
            deploymentArgs.templateHash,
            deploymentArgs.inputBox,
            deploymentArgs.withdrawalConfig,
            deploymentArgs.salt
        );
        assertNotEq(address(frontRunApp), appAddr);
        vm.stopPrank();

        // The self-hosted factory must deploy through the reserved entrypoints,
        // or anyone could front-run it with the salts it derives.
        vm.expectCall(
            address(_authorityFactory),
            abi.encodeWithSelector(IAuthorityFactory.newReservedAuthority.selector)
        );
        vm.expectCall(
            address(_applicationFactory),
            abi.encodeWithSelector(IApplicationFactory.newReservedApplication.selector)
        );

        (IApplication app, IAuthority authority) =
            _factory._deployContracts(deploymentArgs);

        assertEq(address(app), appAddr);
        assertEq(address(authority), authorityAddr);
    }

    function _testDeployContractsSurvivesPartialFrontRun(
        DeploymentArgs memory deploymentArgs,
        DeploymentArgs memory frontRunDeploymentArgs,
        address frontRunner
    ) internal {
        _makeDeploymentArgsValidInPlace(deploymentArgs);
        _makeDeploymentArgsValidInPlace(frontRunDeploymentArgs);
        vm.assume(
            keccak256(abi.encode(frontRunDeploymentArgs))
                != keccak256(abi.encode(deploymentArgs))
        );

        (address appAddr, address authorityAddr) =
            _factory._calculateAddresses(deploymentArgs);

        // A third party copies every argument but one.
        vm.prank(frontRunner);
        (IApplication frontRunApp, IAuthority frontRunAuthority) =
            _factory._deployContracts(frontRunDeploymentArgs);

        assertNotEq(address(frontRunApp), appAddr);
        assertNotEq(address(frontRunAuthority), authorityAddr);

        (IApplication app, IAuthority authority) =
            _factory._deployContracts(deploymentArgs);

        assertEq(address(app), appAddr);
        assertEq(address(authority), authorityAddr);
    }

    function _makeDeploymentArgsValidInPlace(DeploymentArgs memory deploymentArgs)
        internal
        pure
    {
        vm.assume(deploymentArgs.authorityOwner != address(0));
        vm.assume(deploymentArgs.epochLength != 0);
        _makeWithdrawalConfigValidInPlace(deploymentArgs.withdrawalConfig);
    }
}
