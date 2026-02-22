// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Self-hosted Application Factory Test
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin-contracts-5.2.0/access/Ownable.sol";

import {WithdrawalConfig} from "src/common/WithdrawalConfig.sol";
import {AuthorityFactory} from "src/consensus/authority/AuthorityFactory.sol";
import {IAuthority} from "src/consensus/authority/IAuthority.sol";
import {IAuthorityFactory} from "src/consensus/authority/IAuthorityFactory.sol";
import {ApplicationFactory} from "src/dapp/ApplicationFactory.sol";
import {IApplication} from "src/dapp/IApplication.sol";
import {IApplicationFactory} from "src/dapp/IApplicationFactory.sol";
import {ISelfHostedApplicationFactory} from "src/dapp/ISelfHostedApplicationFactory.sol";
import {SelfHostedApplicationFactory} from "src/dapp/SelfHostedApplicationFactory.sol";
import {LibWithdrawalConfig} from "src/library/LibWithdrawalConfig.sol";

import {Test} from "forge-std-1.9.6/src/Test.sol";

contract SelfHostedApplicationFactoryTest is Test {
    using LibWithdrawalConfig for WithdrawalConfig;

    IAuthorityFactory authorityFactory;
    IApplicationFactory applicationFactory;
    ISelfHostedApplicationFactory factory;

    function setUp() external {
        authorityFactory = new AuthorityFactory();
        applicationFactory = new ApplicationFactory();
        factory = new SelfHostedApplicationFactory(authorityFactory, applicationFactory);
    }

    function testGetApplicationContract() external view {
        assertEq(address(factory.getApplicationFactory()), address(applicationFactory));
    }

    function testGetAuthorityFactory() external view {
        assertEq(address(factory.getAuthorityFactory()), address(authorityFactory));
    }

    function testDeployContracts(
        uint256 blockNumber,
        address authorityOwner,
        uint256 epochLength,
        address appOwner,
        bytes32 templateHash,
        bytes calldata dataAvailability,
        WithdrawalConfig calldata withdrawalConfig,
        bytes32 salt
    ) external {
        vm.roll(blockNumber);

        address appAddr;
        address authorityAddr;

        (appAddr, authorityAddr) = factory.calculateAddresses(
            authorityOwner,
            epochLength,
            appOwner,
            templateHash,
            dataAvailability,
            withdrawalConfig,
            salt
        );

        try factory.deployContracts(
            authorityOwner,
            epochLength,
            appOwner,
            templateHash,
            dataAvailability,
            withdrawalConfig,
            salt
        ) returns (
            IApplication application, IAuthority authority
        ) {
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

            assertEq(
                address(application.getOutputsMerkleRootValidator()),
                authorityAddr,
                "app.getOutputsMerkleRootValidator() != authority"
            );
            assertEq(application.owner(), appOwner, "app.owner() != appOwner");
            assertEq(
                application.getTemplateHash(),
                templateHash,
                "app.getTemplateHash() != templateHash"
            );
            assertEq(
                application.getDataAvailability(),
                dataAvailability,
                "app.getDataAvailability() != dataAvailability"
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

            (appAddr, authorityAddr) = factory.calculateAddresses(
                authorityOwner,
                epochLength,
                appOwner,
                templateHash,
                dataAvailability,
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
            assertGe(error.length, 4, "Error data too short (no 4-byte selector)");

            // forge-lint: disable-next-line(unsafe-typecast)
            bytes4 errorSelector = bytes4(error);
            bytes memory errorArgs = new bytes(error.length - 4);

            for (uint256 i; i < errorArgs.length; ++i) {
                errorArgs[i] = error[i + 4];
            }

            if (errorSelector == Ownable.OwnableInvalidOwner.selector) {
                address owner = abi.decode(errorArgs, (address));
                assertEq(owner, address(0), "OwnableInvalidOwner.owner != address(0)");
                assertTrue(
                    appOwner == address(0) || authorityOwner == address(0),
                    "Expected either app or authority owner to be zero"
                );
            } else if (errorSelector == bytes4(keccak256("Error(string)"))) {
                string memory message = abi.decode(errorArgs, (string));
                bytes32 messageHash = keccak256(bytes(message));
                if (messageHash == keccak256("epoch length must not be zero")) {
                    assertEq(epochLength, 0, "Expected epoch length to be zero");
                } else if (messageHash == keccak256("Invalid withdrawal config")) {
                    assertEq(
                        withdrawalConfig.isValid(),
                        false,
                        "expected withdrawal config to be invalid"
                    );
                } else {
                    revert("Unexpected error message");
                }
            } else {
                revert("Unexpected error");
            }
        }
    }
}
