// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Quorum Factory Test
pragma solidity ^0.8.8;

import {QuorumFactory} from "contracts/consensus/quorum/QuorumFactory.sol";
import {Quorum} from "contracts/consensus/quorum/Quorum.sol";
import {Vm} from "forge-std/Vm.sol";

import {TestBase} from "../../util/TestBase.sol";

contract QuorumFactoryTest is TestBase {
    QuorumFactory factory;
    uint256 internal constant QUORUM_MAX_SIZE = 50;

    event QuorumCreated(Quorum quorum);

    function setUp() public {
        factory = new QuorumFactory();
    }

    function testNewQuorum(uint256 seed) public {
        uint256 numOfValidators = bound(seed, 1, QUORUM_MAX_SIZE);
        address[] memory validators = generateAddresses(numOfValidators);

        vm.recordLogs();

        Quorum quorum = factory.newQuorum(validators);

        testNewQuorumAux(validators, quorum);
    }

    function testNewQuorumAux(
        address[] memory validators,
        Quorum quorum
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
                Quorum eventQuorum = abi.decode(entry.data, (Quorum));
                assertEq(address(eventQuorum), address(quorum));
            }
        }
        assertEq(numQuorumCreated, 1);

        uint256 numOfValidators = validators.length;
        assertEq(numOfValidators, quorum.numOfValidators());
        for (uint256 i; i < numOfValidators; ++i) {
            assertEq(validators[i], quorum.validatorById(i + 1));
        }
    }

    function testNewQuorumDeterministic(uint256 seed, bytes32 salt) public {
        uint256 numOfValidators = bound(seed, 1, QUORUM_MAX_SIZE);
        address[] memory validators = generateAddresses(numOfValidators);

        address precalculatedAddress = factory.calculateQuorumAddress(
            validators,
            salt
        );

        vm.recordLogs();

        Quorum quorum = factory.newQuorum(validators, salt);

        testNewQuorumAux(validators, quorum);

        // Precalculated address must match actual address
        assertEq(precalculatedAddress, address(quorum));

        precalculatedAddress = factory.calculateQuorumAddress(validators, salt);

        // Precalculated address must STILL match actual address
        assertEq(precalculatedAddress, address(quorum));

        // Cannot deploy a quorum with the same salt twice
        vm.expectRevert();
        factory.newQuorum(validators, salt);
    }
}
