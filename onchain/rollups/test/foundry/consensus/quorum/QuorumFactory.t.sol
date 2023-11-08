// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Quorum Factory Test
pragma solidity ^0.8.8;

import {QuorumFactory} from "contracts/consensus/quorum/QuorumFactory.sol";
import {Quorum} from "contracts/consensus/quorum/Quorum.sol";
import {IHistory} from "contracts/history/IHistory.sol";
import {Vm} from "forge-std/Vm.sol";

import {TestBase} from "../../util/TestBase.sol";

contract QuorumFactoryTest is TestBase {
    QuorumFactory factory;
    // let there be no more than QUORUM_MAX_SIZE validators for test performance
    uint256 internal constant QUORUM_MAX_SIZE = 1000;

    event QuorumCreated(Quorum quorum, IHistory history);
    struct QuorumCreatedEventData {
        Quorum quorum;
        IHistory history;
    }

    function setUp() public {
        factory = new QuorumFactory();
    }

    function testNewQuorum(uint256 _seed, IHistory _history) public {
        uint256 numOfValidators = bound(_seed, 1, QUORUM_MAX_SIZE);
        address[] memory validators = generateAddresses(numOfValidators);
        uint256[] memory shares = generateArithmeticSequence(numOfValidators);

        vm.recordLogs();

        Quorum quorum = factory.newQuorum(validators, shares, _history);

        testNewQuorumAux(validators, shares, _history, quorum);
    }

    function testNewQuorumAux(
        address[] memory _validators,
        uint256[] memory _shares,
        IHistory _history,
        Quorum _quorum
    ) internal {
        Vm.Log[] memory entries = vm.getRecordedLogs();

        uint256 numQuorumCreated;
        for (uint256 i; i < entries.length; ++i) {
            Vm.Log memory entry = entries[i];

            if (
                entry.emitter == address(factory) &&
                entry.topics[0] == QuorumCreated.selector
            ) {
                ++numQuorumCreated;
                QuorumCreatedEventData memory eventData = abi.decode(
                    entry.data,
                    (QuorumCreatedEventData)
                );
                assertEq(address(eventData.quorum), address(_quorum));
                assertEq(address(eventData.history), address(_history));
            }
        }
        assertEq(numQuorumCreated, 1);

        assertEq(address(_quorum.getHistory()), address(_history));
        address[] memory returnedValidators = _quorum.validators();
        assertEq(returnedValidators, _validators);
        assertEq(_quorum.totalShares(), sum(_shares));
        for (uint256 i; i < _validators.length; ++i) {
            assertEq(_quorum.shares(returnedValidators[i]), _shares[i]);
        }
    }

    function testNewQuorumDeterministic(
        uint256 _seed,
        IHistory _history,
        bytes32 _salt
    ) public {
        uint256 numOfValidators = bound(_seed, 1, QUORUM_MAX_SIZE);
        address[] memory validators = generateAddresses(numOfValidators);
        uint256[] memory shares = generateArithmeticSequence(numOfValidators);

        address precalculatedAddress = factory.calculateQuorumAddress(
            validators,
            shares,
            address(_history),
            _salt
        );

        vm.recordLogs();

        Quorum quorum = factory.newQuorum(validators, shares, _history, _salt);

        testNewQuorumAux(validators, shares, _history, quorum);

        // Precalculated address must match actual address
        assertEq(precalculatedAddress, address(quorum));

        precalculatedAddress = factory.calculateQuorumAddress(
            validators,
            shares,
            address(_history),
            _salt
        );

        // Precalculated address must STILL match actual address
        assertEq(precalculatedAddress, address(quorum));

        // Cannot deploy a quorum with the same salt twice
        vm.expectRevert();
        factory.newQuorum(validators, shares, _history, _salt);
    }
}
