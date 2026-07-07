// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Self-hosted Application Factory Test
pragma solidity ^0.8.30;

import {Ownable} from "@openzeppelin-contracts-5.2.0/access/Ownable.sol";

import {WithdrawalConfig} from "src/common/WithdrawalConfig.sol";
import {IConsensusFactoryErrors} from "src/consensus/IConsensusFactoryErrors.sol";
import {IAuthority} from "src/consensus/authority/IAuthority.sol";
import {IAuthorityFactory} from "src/consensus/authority/IAuthorityFactory.sol";
import {IApplication} from "src/dapp/IApplication.sol";
import {IApplicationFactory} from "src/dapp/IApplicationFactory.sol";
import {IApplicationFactoryErrors} from "src/dapp/IApplicationFactoryErrors.sol";
import {ISelfHostedApplicationFactory} from "src/dapp/ISelfHostedApplicationFactory.sol";
import {IInputBox} from "src/inputs/IInputBox.sol";
import {LibWithdrawalConfig} from "src/library/LibWithdrawalConfig.sol";

import {LibBytes} from "../util/LibBytes.sol";
import {RollupsTest} from "../util/RollupsTest.sol";
import {VersionGetterTestUtils} from "../util/VersionGetterTestUtils.sol";

contract SelfHostedApplicationFactoryTest is RollupsTest, VersionGetterTestUtils {
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
        address authorityOwner,
        uint256 epochLength,
        uint256 claimStagingPeriod,
        bytes32 templateHash,
        IInputBox inputBox,
        WithdrawalConfig calldata withdrawalConfig,
        bytes32 salt
    ) external {
        vm.roll(blockNumber);

        address appAddr;
        address authorityAddr;

        (appAddr, authorityAddr) = _factory.calculateAddresses(
            authorityOwner,
            epochLength,
            claimStagingPeriod,
            templateHash,
            inputBox,
            withdrawalConfig,
            salt
        );

        try _factory.deployContracts(
            authorityOwner,
            epochLength,
            claimStagingPeriod,
            templateHash,
            inputBox,
            withdrawalConfig,
            salt
        ) returns (
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
                authority.owner(), authorityOwner, "authority.owner() != authorityOwner"
            );
            assertEq(
                authority.getEpochLength(),
                epochLength,
                "authority.getEpochLength() != epochLength"
            );
            assertGt(epochLength, 0, "getEpochLength() > 0");
            assertEq(
                authority.getClaimStagingPeriod(),
                claimStagingPeriod,
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
                templateHash,
                "app.getTemplateHash() != templateHash"
            );
            assertEq(
                abi.encode(application.getWithdrawalConfig()),
                abi.encode(withdrawalConfig),
                "app.getWithdrawalConfig() != withdrawalConfig"
            );
            assertEq(
                application.getGuardian(),
                withdrawalConfig.guardian,
                "app.getGuardian() != withdrawalConfig.guardian"
            );
            assertEq(
                application.getLog2LeavesPerAccount(),
                withdrawalConfig.log2LeavesPerAccount,
                "app.getLog2LeavesPerAccount() != withdrawalConfig.log2LeavesPerAccount"
            );
            assertEq(
                application.getLog2MaxNumOfAccounts(),
                withdrawalConfig.log2MaxNumOfAccounts,
                "app.getLog2MaxNumOfAccounts() != withdrawalConfig.log2MaxNumOfAccounts"
            );
            assertEq(
                application.getAccountsDriveStartIndex(),
                withdrawalConfig.accountsDriveStartIndex,
                "app.getAccountsDriveStartIndex() != withdrawalConfig.accountsDriveStartIndex"
            );
            assertEq(
                address(application.getWithdrawalOutputBuilder()),
                address(withdrawalConfig.withdrawalOutputBuilder),
                "app.getWithdrawalOutputBuilder() != withdrawalConfig.withdrawalOutputBuilder"
            );
            assertEq(
                address(application.getInputBox()),
                address(inputBox),
                "app.getInputBox() != inputBox"
            );
            assertEq(
                application.getDeploymentBlockNumber(),
                blockNumber,
                "getDeploymentBlockNumber() != blockNumber"
            );
            assertEq(
                withdrawalConfig.isValid(), true, "Expected withdrawal config to be valid"
            );
            assertEq(application.isForeclosed(), false, "isForeclosed() != false");

            (appAddr, authorityAddr) = _factory.calculateAddresses(
                authorityOwner,
                epochLength,
                claimStagingPeriod,
                templateHash,
                inputBox,
                withdrawalConfig,
                salt
            );

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
        } catch (bytes memory error) {
            (bytes4 errorSelector, bytes memory errorArgs) = error.consumeBytes4();
            if (errorSelector == Ownable.OwnableInvalidOwner.selector) {
                address owner = abi.decode(errorArgs, (address));
                assertEq(owner, address(0), "OwnableInvalidOwner.owner != address(0)");
                assertTrue(
                    authorityOwner == address(0),
                    "Expected either app or authority owner to be zero"
                );
            } else if (errorSelector == IConsensusFactoryErrors.ZeroEpochLength.selector)
            {
                assertEq(errorArgs.length, 0, "expected ZeroEpochLength to have no args");
                assertEq(epochLength, 0, "expected epoch length to be zero");
            } else if (
                errorSelector
                    == IApplicationFactoryErrors.InvalidWithdrawalConfig.selector
            ) {
                assertEq(
                    errorArgs,
                    abi.encode(withdrawalConfig),
                    "InvalidWithdrawalConfig.withdrawalConfig != withdrawalConfig"
                );
                assertFalse(
                    withdrawalConfig.isValid(), "expected withdrawal config to be invalid"
                );
            } else {
                revert("Unexpected error");
            }
        }
    }
}
