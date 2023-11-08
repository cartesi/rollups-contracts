// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Authority-History Pair Factory Test
pragma solidity ^0.8.8;

import {Test} from "forge-std/Test.sol";
import {AuthorityHistoryPairFactory} from "contracts/consensus/authority/AuthorityHistoryPairFactory.sol";
import {IAuthorityFactory} from "contracts/consensus/authority/IAuthorityFactory.sol";
import {AuthorityFactory} from "contracts/consensus/authority/AuthorityFactory.sol";
import {Authority} from "contracts/consensus/authority/Authority.sol";
import {IHistoryFactory} from "contracts/history/IHistoryFactory.sol";
import {HistoryFactory} from "contracts/history/HistoryFactory.sol";
import {History} from "contracts/history/History.sol";
import {IHistory} from "contracts/history/IHistory.sol";
import {Vm} from "forge-std/Vm.sol";

contract AuthorityHistoryPairFactoryTest is Test {
    AuthorityFactory authorityFactory;
    HistoryFactory historyFactory;
    AuthorityHistoryPairFactory factory;

    event AuthorityHistoryPairFactoryCreated(
        IAuthorityFactory authorityFactory,
        IHistoryFactory historyFactory
    );

    struct FactoryCreatedEventData {
        IAuthorityFactory authorityFactory;
        IHistoryFactory historyFactory;
    }

    event AuthorityCreated(address authorityOwner, Authority authority);

    struct AuthorityCreatedEventData {
        address authorityOwner;
        Authority authority;
    }

    event HistoryCreated(address historyOwner, History history);

    struct HistoryCreatedEventData {
        address historyOwner;
        History history;
    }

    event NewHistory(IHistory history);

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    function setUp() public {
        authorityFactory = new AuthorityFactory();
        historyFactory = new HistoryFactory();
        factory = new AuthorityHistoryPairFactory(
            authorityFactory,
            historyFactory
        );
    }

    function testFactoryCreation() public {
        vm.recordLogs();

        factory = new AuthorityHistoryPairFactory(
            authorityFactory,
            historyFactory
        );

        Vm.Log[] memory entries = vm.getRecordedLogs();

        uint256 numOfFactoryCreated;

        for (uint256 i; i < entries.length; ++i) {
            Vm.Log memory entry = entries[i];

            if (
                entry.emitter == address(factory) &&
                entry.topics[0] == AuthorityHistoryPairFactoryCreated.selector
            ) {
                ++numOfFactoryCreated;

                FactoryCreatedEventData memory eventData;

                eventData = abi.decode(entry.data, (FactoryCreatedEventData));

                assertEq(
                    address(authorityFactory),
                    address(eventData.authorityFactory)
                );
                assertEq(
                    address(historyFactory),
                    address(eventData.historyFactory)
                );
            }
        }

        assertEq(numOfFactoryCreated, 1);

        assertEq(
            address(factory.getAuthorityFactory()),
            address(authorityFactory)
        );
        assertEq(address(factory.getHistoryFactory()), address(historyFactory));
    }

    function testNewAuthorityHistoryPair(address _authorityOwner) public {
        vm.assume(_authorityOwner != address(0));

        vm.recordLogs();

        (Authority authority, History history) = factory
            .newAuthorityHistoryPair(_authorityOwner);

        testNewAuthorityHistoryPairAux(_authorityOwner, authority, history);
    }

    function testNewAuthorityHistoryPairAux(
        address _authorityOwner,
        Authority _authority,
        History _history
    ) internal {
        Vm.Log[] memory entries = vm.getRecordedLogs();

        uint256 numOfAuthorityCreated;
        uint256 numOfHistoryCreated;
        uint256 numOfNewHistory;
        uint256 numOfAuthorityOwnershipTransferred;
        uint256 numOfHistoryOwnershipTransferred;

        for (uint256 i; i < entries.length; ++i) {
            Vm.Log memory entry = entries[i];

            if (
                entry.emitter == address(authorityFactory) &&
                entry.topics[0] == AuthorityCreated.selector
            ) {
                ++numOfAuthorityCreated;

                AuthorityCreatedEventData memory eventData;

                eventData = abi.decode(entry.data, (AuthorityCreatedEventData));

                assertEq(address(factory), eventData.authorityOwner);
                assertEq(address(_authority), address(eventData.authority));
            }

            if (
                entry.emitter == address(historyFactory) &&
                entry.topics[0] == HistoryCreated.selector
            ) {
                ++numOfHistoryCreated;

                HistoryCreatedEventData memory eventData;

                eventData = abi.decode(entry.data, (HistoryCreatedEventData));

                assertEq(address(_authority), eventData.historyOwner);
                assertEq(address(_history), address(eventData.history));
            }

            if (
                entry.emitter == address(_authority) &&
                entry.topics[0] == NewHistory.selector
            ) {
                ++numOfNewHistory;

                IHistory history = abi.decode(entry.data, (IHistory));

                assertEq(address(_history), address(history));
            }

            if (
                entry.emitter == address(_authority) &&
                entry.topics[0] == OwnershipTransferred.selector
            ) {
                ++numOfAuthorityOwnershipTransferred;

                address a = address(uint160(uint256(entry.topics[1])));
                address b = address(uint160(uint256(entry.topics[2])));

                if (numOfAuthorityOwnershipTransferred == 1) {
                    assertEq(address(0), a);
                    assertEq(address(authorityFactory), b);
                } else if (numOfAuthorityOwnershipTransferred == 2) {
                    assertEq(address(authorityFactory), a);
                    assertEq(address(factory), b);
                } else if (numOfAuthorityOwnershipTransferred == 3) {
                    assertEq(address(factory), a);
                    assertEq(address(_authorityOwner), b);
                }
            }

            if (
                entry.emitter == address(_history) &&
                entry.topics[0] == OwnershipTransferred.selector
            ) {
                ++numOfHistoryOwnershipTransferred;

                address a = address(uint160(uint256(entry.topics[1])));
                address b = address(uint160(uint256(entry.topics[2])));

                if (numOfHistoryOwnershipTransferred == 1) {
                    assertEq(address(0), a);
                    assertEq(address(historyFactory), b);
                } else if (numOfHistoryOwnershipTransferred == 2) {
                    assertEq(address(historyFactory), a);
                    assertEq(address(_authority), b);
                }
            }
        }

        assertEq(numOfAuthorityCreated, 1);
        assertEq(numOfHistoryCreated, 1);
        assertEq(numOfNewHistory, 1);
        assertEq(numOfAuthorityOwnershipTransferred, 3);
        assertEq(numOfHistoryOwnershipTransferred, 2);

        assertEq(address(_authority.owner()), _authorityOwner);
        assertEq(address(_authority.getHistory()), address(_history));
        assertEq(address(_history.owner()), address(_authority));
    }

    function testNewAuthorityHistoryPairDeterministic(
        address _authorityOwner,
        bytes32 _salt
    ) public {
        vm.assume(_authorityOwner != address(0));

        (address authorityAddress, address historyAddress) = factory
            .calculateAuthorityHistoryAddressPair(_authorityOwner, _salt);

        vm.recordLogs();

        (Authority authority, History history) = factory
            .newAuthorityHistoryPair(_authorityOwner, _salt);

        testNewAuthorityHistoryPairAux(_authorityOwner, authority, history);

        // Precalculated addresses must match actual addresses
        assertEq(authorityAddress, address(authority));
        assertEq(historyAddress, address(history));

        (authorityAddress, historyAddress) = factory
            .calculateAuthorityHistoryAddressPair(_authorityOwner, _salt);

        // Precalculated addresses must STILL match actual addresses
        assertEq(authorityAddress, address(authority));
        assertEq(historyAddress, address(history));

        // Cannot deploy an authority-history pair with the same salt twice
        vm.expectRevert();
        factory.newAuthorityHistoryPair(_authorityOwner, _salt);
    }
}
