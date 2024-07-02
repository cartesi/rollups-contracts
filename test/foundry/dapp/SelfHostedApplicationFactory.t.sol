// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Self-hosted Application Factory Test
pragma solidity ^0.8.22;

import {IAuthorityFactory} from "contracts/consensus/authority/IAuthorityFactory.sol";
import {AuthorityFactory} from "contracts/consensus/authority/AuthorityFactory.sol";
import {Authority} from "contracts/consensus/authority/Authority.sol";
import {IApplicationFactory} from "contracts/dapp/IApplicationFactory.sol";
import {ApplicationFactory} from "contracts/dapp/ApplicationFactory.sol";
import {Application} from "contracts/dapp/Application.sol";
import {ISelfHostedApplicationFactory} from "contracts/dapp/ISelfHostedApplicationFactory.sol";
import {SelfHostedApplicationFactory} from "contracts/dapp/SelfHostedApplicationFactory.sol";
import {TestBase} from "../util/TestBase.sol";

contract SelfHostedApplicationFactoryTest is TestBase {
    IAuthorityFactory authorityFactory;
    IApplicationFactory applicationFactory;
    ISelfHostedApplicationFactory factory;

    function setUp() external {
        authorityFactory = new AuthorityFactory();
        applicationFactory = new ApplicationFactory();
        factory = new SelfHostedApplicationFactory(
            authorityFactory,
            applicationFactory
        );
    }

    function testGetApplicationContract() external view {
        assertEq(
            address(factory.getApplicationFactory()),
            address(applicationFactory)
        );
    }

    function testGetAuthorityFactory() external view {
        assertEq(
            address(factory.getAuthorityFactory()),
            address(authorityFactory)
        );
    }

    function testDeployContracts(
        address authorityOwner,
        address appOwner,
        bytes32 templateHash,
        bytes32 salt
    ) external {
        vm.assume(appOwner != address(0));
        vm.assume(authorityOwner != address(0));

        address appAddr;
        address authorityAddr;

        (appAddr, authorityAddr) = factory.calculateAddresses(
            authorityOwner,
            appOwner,
            templateHash,
            salt
        );

        Application application;
        Authority authority;

        (application, authority) = factory.deployContracts(
            authorityOwner,
            appOwner,
            templateHash,
            salt
        );

        assertEq(appAddr, address(application));
        assertEq(authorityAddr, address(authority));

        assertEq(authority.owner(), authorityOwner);

        assertEq(address(application.getConsensus()), authorityAddr);
        assertEq(application.owner(), appOwner);
        assertEq(application.getTemplateHash(), templateHash);
    }
}
