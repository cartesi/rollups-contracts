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

    function setUp() public {
        factory = new QuorumFactory();
    }

    function testNewQuorum(
        uint256 _numValidators
    ) public {
        vm.assume(_numValidators>1);
        vm.assume(_numValidators<50);

        address[] memory quorumValidators = generateValidators(_numValidators);
        uint256[] memory shares = generateShares(quorumValidators);

        IHistory history = new History(msg.sender);

        vm.recordLogs();

        Quorum quorum = factory.newQuorum(quorumValidators, shares, history);

        emit QuorumCreated(quorumValidators, quorum);

        //assertEq(quorum.getHistory() == bytes32(history);
        //decodeFactoryLogs(quorumValidators, quorum);
    }

    function testNewQuorumDeterministic(
        uint256 _numValidators,
        bytes32 _salt
    ) public {
        vm.assume(_numValidators>1);
        vm.assume(_numValidators<50);

        address[] memory quorumValidators = generateValidators(_numValidators);
        uint256[] memory shares = generateShares(quorumValidators);

        IHistory history = new History(msg.sender);

        address precalculatedAddress = factory.calculateQuorumAddress(quorumValidators, shares, history, _salt);

        vm.recordLogs();

        Quorum quorum = factory.newQuorum(quorumValidators, shares, history, _salt);

        emit QuorumCreated(quorumValidators, quorum);

        // Precalculated address must match actual address
        assertEq(precalculatedAddress, address(quorum));
    }

    function testAlreadyDeployedNewQuorumDeterministic(
        uint256 _numValidators,
        bytes32 _salt
    ) public {
        vm.assume(_numValidators>1);
        vm.assume(_numValidators<50);

        address[] memory quorumValidators = generateValidators(_numValidators);
        uint256[] memory shares = generateShares(quorumValidators);

        IHistory history = new History(msg.sender);

        factory.newQuorum(quorumValidators, shares, history, _salt);

        //Deploy already deployed quorum
        vm.expectRevert();
        factory.newQuorum(quorumValidators, shares, history, _salt);
    }
    
    // HELPER FUNCTIONS
    function generateValidators(uint256 _numValidators) internal returns(address[] memory){
        address[] memory validators = new address[](_numValidators);
        for (uint256 i = 0; i < _numValidators; i++) {
            validators[i] = vm.addr(i+1);
        }
        return validators;
    }

    function generateShares(address[] memory validators) internal returns(uint256[] memory){
        //generate a random number of shares for each validator
        uint256[] memory shares = new uint256[](validators.length);
        for (uint256 i; i < shares.length; ++i) {
            uint256 share = uint256(
                keccak256(abi.encodePacked(i, validators[i]))) % 100;
            shares[i] = (share > 0) ? share : validators.length;
        }
        return shares;
    }

    /*function decodeFactoryLogs(address[] memory _quorumValidators, Quorum quorum) internal {
        Vm.Log[] memory entries = vm.getRecordedLogs();

        address[] memory a;
        address b;

        (a, b) = abi.decode(entries[0].data, (address[], address));

        assertEq(_quorumValidators, a); //entry.emitter == address(factory)
        assertEq(address(quorum), b);
    }*/
}


