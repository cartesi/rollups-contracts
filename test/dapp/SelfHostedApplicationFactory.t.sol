// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Self-hosted Application Factory Test
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin-contracts-5.2.0/access/Ownable.sol";

import {IAuthorityFactory} from "src/consensus/authority/IAuthorityFactory.sol";
import {AuthorityFactory} from "src/consensus/authority/AuthorityFactory.sol";
import {IAuthority} from "src/consensus/authority/IAuthority.sol";
import {IApplicationFactory} from "src/dapp/IApplicationFactory.sol";
import {ApplicationFactory} from "src/dapp/ApplicationFactory.sol";
import {IApplication} from "src/dapp/IApplication.sol";
import {ISelfHostedApplicationFactory} from "src/dapp/ISelfHostedApplicationFactory.sol";
import {SelfHostedApplicationFactory} from "src/dapp/SelfHostedApplicationFactory.sol";

import {Test} from "forge-std-1.9.6/src/Test.sol";

contract SelfHostedApplicationFactoryTest is Test {
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

    function testRevertsAuthorityOwnerAddressZero(
        uint256 epochLength,
        address appOwner,
        bytes32 templateHash,
        bytes calldata dataAvailability,
        bytes32 salt
    ) external {
        vm.assume(appOwner != address(0));
        vm.assume(epochLength > 0);

        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0))
        );
        factory.deployContracts(
            address(0), epochLength, appOwner, templateHash, dataAvailability, salt
        );
    }

    function testRevertsEpochLengthZero(
        address authorityOwner,
        address appOwner,
        bytes32 templateHash,
        bytes calldata dataAvailability,
        bytes32 salt
    ) external {
        vm.assume(appOwner != address(0));
        vm.assume(authorityOwner != address(0));

        vm.expectRevert("epoch length must not be zero");
        factory.deployContracts(
            authorityOwner, 0, appOwner, templateHash, dataAvailability, salt
        );
    }

    function testRevertsApplicationOwnerAddressZero(
        address authorityOwner,
        uint256 epochLength,
        bytes32 templateHash,
        bytes calldata dataAvailability,
        bytes32 salt
    ) external {
        vm.assume(authorityOwner != address(0));
        vm.assume(epochLength > 0);

        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0))
        );
        factory.deployContracts(
            authorityOwner, epochLength, address(0), templateHash, dataAvailability, salt
        );
    }

    function testDeployContracts(
        address authorityOwner,
        uint256 epochLength,
        address appOwner,
        bytes32 templateHash,
        bytes calldata dataAvailability,
        bytes32 salt
    ) external {
        vm.assume(appOwner != address(0));
        vm.assume(authorityOwner != address(0));
        vm.assume(epochLength > 0);

        IApplication application;
        IAuthority authority;

        (application, authority) = factory.deployContracts(
            authorityOwner, epochLength, appOwner, templateHash, dataAvailability, salt
        );

        assertEq(authority.owner(), authorityOwner);
        assertEq(authority.getEpochLength(), epochLength);

        assertEq(address(application.getOutputsMerkleRootValidator()), address(authority));
        assertEq(application.owner(), appOwner);
        assertEq(application.getTemplateHash(), templateHash);
        assertEq(application.getDataAvailability(), dataAvailability);
    }
}
