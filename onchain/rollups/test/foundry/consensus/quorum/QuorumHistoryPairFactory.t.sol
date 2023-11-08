// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Quorum-History Pair Factory Test
pragma solidity ^0.8.8;

import {QuorumHistoryPairFactory} from "contracts/consensus/quorum/QuorumHistoryPairFactory.sol";
import {IQuorumFactory} from "contracts/consensus/quorum/IQuorumFactory.sol";
import {QuorumFactory} from "contracts/consensus/quorum/QuorumFactory.sol";
import {Quorum} from "contracts/consensus/quorum/Quorum.sol";
import {IHistoryFactory} from "contracts/history/IHistoryFactory.sol";
import {HistoryFactory} from "contracts/history/HistoryFactory.sol";
import {History} from "contracts/history/History.sol";
import {IHistory} from "contracts/history/IHistory.sol";
import {Vm} from "forge-std/Vm.sol";

import {TestBase} from "../../util/TestBase.sol";

contract QuorumHistoryPairFactoryTest is TestBase {
    QuorumFactory quorumFactory;
    HistoryFactory historyFactory;
    QuorumHistoryPairFactory factory;
    // let there be no more than QUORUM_MAX_SIZE validators for test performance
    uint256 internal constant QUORUM_MAX_SIZE = 1000;

    event QuorumHistoryPairFactoryCreated(
        IQuorumFactory quorumFactory,
        IHistoryFactory historyFactory
    );
    struct FactoryCreatedEventData {
        IQuorumFactory quorumFactory;
        IHistoryFactory historyFactory;
    }

    event HistoryCreated(address historyOwner, History history);
    struct HistoryCreatedEventData {
        address historyOwner;
        History history;
    }

    event QuorumCreated(Quorum quorum, IHistory history);
    struct QuorumCreatedEventData {
        Quorum quorum;
        IHistory history;
    }

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    function setUp() public {
        quorumFactory = new QuorumFactory();
        historyFactory = new HistoryFactory();
        factory = new QuorumHistoryPairFactory(quorumFactory, historyFactory);
    }

    function testFactoryCreation() public {
        vm.recordLogs();

        factory = new QuorumHistoryPairFactory(quorumFactory, historyFactory);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        uint256 numOfFactoryCreated;

        for (uint256 i; i < entries.length; ++i) {
            Vm.Log memory entry = entries[i];

            if (
                entry.emitter == address(factory) &&
                entry.topics[0] == QuorumHistoryPairFactoryCreated.selector
            ) {
                ++numOfFactoryCreated;

                FactoryCreatedEventData memory eventData;

                eventData = abi.decode(entry.data, (FactoryCreatedEventData));

                assertEq(
                    address(quorumFactory),
                    address(eventData.quorumFactory)
                );
                assertEq(
                    address(historyFactory),
                    address(eventData.historyFactory)
                );
            }
        }

        assertEq(numOfFactoryCreated, 1);

        assertEq(address(factory.getQuorumFactory()), address(quorumFactory));
        assertEq(address(factory.getHistoryFactory()), address(historyFactory));
    }

    function testNewQuorumHistoryPair(uint256 _seed) public {
        uint256 numOfValidators = bound(_seed, 1, QUORUM_MAX_SIZE);
        address[] memory validators = generateAddresses(numOfValidators);
        uint256[] memory shares = generateArithmeticSequence(numOfValidators);

        vm.recordLogs();

        (Quorum quorum, History history) = factory.newQuorumHistoryPair(
            validators,
            shares
        );

        testNewQuorumHistoryPairAux(validators, shares, quorum, history);
    }

    function testNewQuorumHistoryPairAux(
        address[] memory _validators,
        uint256[] memory _shares,
        Quorum _quorum,
        History _history
    ) internal {
        Vm.Log[] memory entries = vm.getRecordedLogs();

        uint256 numOfHistoryCreated;
        uint256 numOfQuorumCreated;
        uint256 numOfHistoryOwnershipTransferred;

        for (uint256 i; i < entries.length; ++i) {
            Vm.Log memory entry = entries[i];

            if (
                entry.emitter == address(historyFactory) &&
                entry.topics[0] == HistoryCreated.selector
            ) {
                ++numOfHistoryCreated;

                HistoryCreatedEventData memory eventData;

                eventData = abi.decode(entry.data, (HistoryCreatedEventData));

                assertEq(address(factory), eventData.historyOwner);
                assertEq(address(_history), address(eventData.history));
            }

            if (
                entry.emitter == address(quorumFactory) &&
                entry.topics[0] == QuorumCreated.selector
            ) {
                ++numOfQuorumCreated;

                QuorumCreatedEventData memory eventData;

                eventData = abi.decode(entry.data, (QuorumCreatedEventData));

                assertEq(address(_quorum), address(eventData.quorum));
                assertEq(address(_history), address(eventData.history));
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
                    assertEq(address(factory), b);
                } else if (numOfHistoryOwnershipTransferred == 3) {
                    assertEq(address(factory), a);
                    assertEq(address(_quorum), b);
                }
            }
        }

        assertEq(numOfHistoryCreated, 1);
        assertEq(numOfQuorumCreated, 1);
        assertEq(numOfHistoryOwnershipTransferred, 3);

        assertEq(address(_quorum.getHistory()), address(_history));
        address[] memory returnedValidators = _quorum.validators();
        assertEq(returnedValidators, _validators);
        assertEq(_quorum.totalShares(), sum(_shares));
        for (uint256 i; i < _validators.length; ++i) {
            assertEq(_quorum.shares(returnedValidators[i]), _shares[i]);
        }
        assertEq(address(_history.owner()), address(_quorum));
    }

    function testNewQuorumHistoryPairDeterministic(
        uint256 _seed,
        bytes32 _salt
    ) public {
        uint256 numOfValidators = bound(_seed, 1, QUORUM_MAX_SIZE);
        address[] memory validators = generateAddresses(numOfValidators);
        uint256[] memory shares = generateArithmeticSequence(numOfValidators);

        (address quorumAddress, address historyAddress) = factory
            .calculateQuorumHistoryAddressPair(validators, shares, _salt);

        vm.recordLogs();

        (Quorum quorum, History history) = factory.newQuorumHistoryPair(
            validators,
            shares,
            _salt
        );

        testNewQuorumHistoryPairAux(validators, shares, quorum, history);

        // Precalculated addresses must match actual addresses
        assertEq(quorumAddress, address(quorum));
        assertEq(historyAddress, address(history));

        (quorumAddress, historyAddress) = factory
            .calculateQuorumHistoryAddressPair(validators, shares, _salt);

        // Precalculated addresses must STILL match actual addresses
        assertEq(quorumAddress, address(quorum));
        assertEq(historyAddress, address(history));

        // Cannot deploy an quorum-history pair with the same salt twice
        vm.expectRevert();
        factory.newQuorumHistoryPair(validators, shares, _salt);
    }
}
