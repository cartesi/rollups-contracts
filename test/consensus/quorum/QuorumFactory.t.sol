// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Quorum Factory Test
pragma solidity ^0.8.22;

import {QuorumFactory} from "src/consensus/quorum/QuorumFactory.sol";
import {IQuorumFactory} from "src/consensus/quorum/IQuorumFactory.sol";
import {IQuorum} from "src/consensus/quorum/IQuorum.sol";

import {Vm} from "forge-std-1.9.6/src/Vm.sol";
import {Test} from "forge-std-1.9.6/src/Test.sol";

import {LibAddressArray} from "../../util/LibAddressArray.sol";

contract QuorumFactoryTest is Test {
    using LibAddressArray for Vm;

    uint256 constant _QUORUM_MAX_SIZE = 50;
    QuorumFactory _factory;

    function setUp() public {
        _factory = new QuorumFactory();
    }

    function testRevertsEpochLengthZero(uint256 seed, bytes32 salt) public {
        uint256 numOfValidators = bound(seed, 1, _QUORUM_MAX_SIZE);
        address[] memory validators = vm.addrs(numOfValidators);

        vm.expectRevert("epoch length must not be zero");
        _factory.newQuorum(validators, 0, salt);
    }

    function testNewQuorumDeterministic(uint256 seed, uint256 epochLength, bytes32 salt)
        public
    {
        vm.assume(epochLength > 0);

        uint256 numOfValidators = bound(seed, 1, _QUORUM_MAX_SIZE);
        address[] memory validators = vm.addrs(numOfValidators);

        address precalculatedAddress =
            _factory.calculateQuorumAddress(validators, epochLength, salt);

        vm.recordLogs();

        IQuorum quorum = _factory.newQuorum(validators, epochLength, salt);

        _testNewQuorumAux(validators, epochLength, quorum);

        // Precalculated address must match actual address
        assertEq(precalculatedAddress, address(quorum));

        precalculatedAddress =
            _factory.calculateQuorumAddress(validators, epochLength, salt);

        // Precalculated address must STILL match actual address
        assertEq(precalculatedAddress, address(quorum));

        // Cannot deploy a quorum with the same salt twice
        vm.expectRevert();
        _factory.newQuorum(validators, epochLength, salt);
    }

    function _testNewQuorumAux(
        address[] memory validators,
        uint256 epochLength,
        IQuorum quorum
    ) internal {
        Vm.Log[] memory entries = vm.getRecordedLogs();

        uint256 numQuorumCreated;
        for (uint256 i; i < entries.length; ++i) {
            Vm.Log memory entry = entries[i];

            if (
                entry.emitter == address(_factory)
                    && entry.topics[0] == IQuorumFactory.QuorumCreated.selector
            ) {
                ++numQuorumCreated;
                IQuorum eventQuorum = abi.decode(entry.data, (IQuorum));
                assertEq(address(eventQuorum), address(quorum));
            }
        }
        assertEq(numQuorumCreated, 1);

        uint256 numOfValidators = validators.length;
        assertEq(numOfValidators, quorum.numOfValidators());
        for (uint256 i; i < numOfValidators; ++i) {
            assertEq(validators[i], quorum.validatorById(i + 1));
        }

        assertEq(epochLength, quorum.getEpochLength());
    }
}
