// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {AuthorityFactory} from "contracts/consensus/authority/AuthorityFactory.sol";
import {AuthorityHistoryPairFactory} from "contracts/consensus/authority/AuthorityHistoryPairFactory.sol";
import {Authority} from "contracts/consensus/authority/Authority.sol";
import {CartesiDAppFactory} from "contracts/dapp/CartesiDAppFactory.sol";
import {CartesiDApp} from "contracts/dapp/CartesiDApp.sol";
import {HistoryFactory} from "contracts/history/HistoryFactory.sol";
import {History} from "contracts/history/History.sol";
import {IAuthorityFactory} from "contracts/consensus/authority/IAuthorityFactory.sol";
import {IAuthorityHistoryPairFactory} from "contracts/consensus/authority/IAuthorityHistoryPairFactory.sol";
import {ICartesiDAppFactory} from "contracts/dapp/ICartesiDAppFactory.sol";
import {IHistoryFactory} from "contracts/history/IHistoryFactory.sol";
import {ISelfHostedApplicationFactory} from "contracts/dapp/ISelfHostedApplicationFactory.sol";
import {SelfHostedApplicationFactory} from "contracts/dapp/SelfHostedApplicationFactory.sol";
import {TestBase} from "../util/TestBase.sol";

/// @title Self-hosted Application Factory Test
contract SelfHostedApplicationFactoryTest is TestBase {
    IHistoryFactory historyFactory;
    IAuthorityFactory authorityFactory;
    IAuthorityHistoryPairFactory authorityHistoryPairFactory;
    ICartesiDAppFactory applicationFactory;
    ISelfHostedApplicationFactory factory;

    function setUp() external {
        historyFactory = new HistoryFactory();
        authorityFactory = new AuthorityFactory();
        authorityHistoryPairFactory = new AuthorityHistoryPairFactory(
            authorityFactory,
            historyFactory
        );
        applicationFactory = new CartesiDAppFactory();
        factory = new SelfHostedApplicationFactory(
            authorityHistoryPairFactory,
            applicationFactory
        );
    }

    function testGetApplicationContract() external {
        assertEq(
            address(factory.getApplicationFactory()),
            address(applicationFactory)
        );
    }

    function testGetAuthorityHistoryPairFactory() external {
        assertEq(
            address(factory.getAuthorityHistoryPairFactory()),
            address(authorityHistoryPairFactory)
        );
    }

    function testDeployContracts(
        address _authorityOwner,
        address _dappOwner,
        bytes32 _templateHash,
        bytes32 _salt
    ) external {
        vm.assume(_dappOwner != address(0));
        vm.assume(_authorityOwner != address(0));

        address appAddr;
        address authorityAddr;
        address historyAddr;

        (appAddr, authorityAddr, historyAddr) = factory.calculateAddresses(
            _authorityOwner,
            _dappOwner,
            _templateHash,
            _salt
        );

        CartesiDApp application;
        Authority authority;
        History history;

        (application, authority, history) = factory.deployContracts(
            _authorityOwner,
            _dappOwner,
            _templateHash,
            _salt
        );

        assertEq(appAddr, address(application));
        assertEq(authorityAddr, address(authority));
        assertEq(historyAddr, address(history));

        assertEq(address(application.getConsensus()), authorityAddr);
        assertEq(address(authority.getHistory()), historyAddr);
        assertEq(history.owner(), authorityAddr);

        assertEq(authority.owner(), _authorityOwner);
        assertEq(application.owner(), _dappOwner);
        assertEq(application.getTemplateHash(), _templateHash);
    }
}
