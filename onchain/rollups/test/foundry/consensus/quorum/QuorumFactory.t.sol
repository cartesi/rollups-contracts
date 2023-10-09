// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {Vm} from "forge-std/Vm.sol";

import {QuorumFactory} from "contracts/consensus/quorum/QuorumFactory.sol";
import {Quorum} from "contracts/consensus/quorum/Quorum.sol";
import {History} from "contracts/history/History.sol";
import {IHistory} from "contracts/history/IHistory.sol";

import {TestBase} from "../../util/TestBase.sol";

import "forge-std/console.sol";

contract QuorumFactoryTest is TestBase {
    QuorumFactory factory;

    event QuorumCreated(address[] quorumValidators, Quorum quorum);

    struct QuorumCreatedEvent {
        address[] quorumValidators;
        Quorum quorum;
    }

    function setUp() public {
        factory = new QuorumFactory();
    }

    function testNewQuorum(uint256 _numValidators) public {
        _numValidators = bound(_numValidators,2,50);
        vm.assume(_numValidators >= 2 && _numValidators <= 50);

        address[] memory quorumValidators = generateValidators(_numValidators);
        uint256[] memory shares = generateShares(quorumValidators);

        IHistory history = new History(msg.sender);

        vm.recordLogs();

        Quorum quorum = factory.newQuorum(quorumValidators, shares, history);

        emit QuorumCreated(quorumValidators, quorum);

        decodeFactoryLogs(quorumValidators, quorum);
    }

    function testNewQuorumDeterministic(
        uint256 _numValidators,
        bytes32 _salt
    ) public {
        _numValidators = bound(_numValidators,2,50);
        vm.assume(_numValidators >= 2 && _numValidators <= 50);

        address[] memory quorumValidators = generateValidators(_numValidators);
        uint256[] memory shares = generateShares(quorumValidators);

        IHistory history = new History(msg.sender);

        address precalculatedAddress = factory.calculateQuorumAddress(
            quorumValidators,
            shares,
            history,
            _salt
        );

        vm.recordLogs();

        Quorum quorum = factory.newQuorum(
            quorumValidators,
            shares,
            history,
            _salt
        );

        emit QuorumCreated(quorumValidators, quorum);

        // Precalculated address must match actual address
        assertEq(precalculatedAddress, address(quorum));
        decodeFactoryLogs(quorumValidators, quorum);
    }

    function testAlreadyDeployedNewQuorumDeterministic(
        uint256 _numValidators,
        bytes32 _salt
    ) public {
        vm.assume(_numValidators > 1);
        vm.assume(_numValidators < 50);

        address[] memory quorumValidators = generateValidators(_numValidators);
        uint256[] memory shares = generateShares(quorumValidators);

        IHistory history = new History(msg.sender);

        factory.newQuorum(quorumValidators, shares, history, _salt);

        //Deploy already deployed quorum
        vm.expectRevert();
        factory.newQuorum(quorumValidators, shares, history, _salt);
    }

    // HELPER FUNCTIONS
    function generateValidators(
        uint256 _numValidators
    ) internal pure returns (address[] memory) {
        address[] memory validators = new address[](_numValidators);
        for (uint256 i = 0; i < _numValidators; i++) {
            validators[i] = vm.addr(i + 1);
        }
        return validators;
    }

    function generateShares(
        address[] memory validators
    ) internal pure returns (uint256[] memory) {
        //generate a random number of shares for each validator
        uint256[] memory shares = new uint256[](validators.length);
        for (uint256 i; i < shares.length; ++i) {
            uint256 share = uint256(
                keccak256(abi.encodePacked(i, validators[i]))
            ) % 100;
            shares[i] = (share > 0) ? share : ++share;
        }
        return shares;
    }

    function checkFactoryLogs(
        address[] memory _quorumValidators,
        Quorum quorum
    ) internal {
        Vm.Log[] memory entries = vm.getRecordedLogs();
        uint256 numOfQuorumsCreated; 

        for (uint256 i = 0; i < entries.length; i++) {
            Vm.Log memory entry = entries[i];

            if (
                entry.topics[0] == QuorumCreated.selector &&
                entry.emitter == address(factory)
            ) {
                ++numOfQuorumsCreated; 
                QuorumCreatedEvent memory quorumEvent;
                (quorumEvent.quorumValidators, quorumEvent.quorum) = abi.decode(
                    entry.data,
                    (address[], Quorum)
                );

                //Validators length in decoded data should match the data passed to the event
                assertEq(
                    _quorumValidators.length,
                    quorumEvent.quorumValidators.length
                );

                //Compare each validator
                for (uint j = 0; j < quorumEvent.quorumValidators.length; j++) {
                    assertEq(
                        _quorumValidators[j],
                        quorumEvent.quorumValidators[j]
                    );
                }

                //Compare quorum address
                assertEq(address(quorum), address(quorumEvent.quorum));
                assertEq(numOfQuorumsCreated, 1); 
            }
        }
    }
}
