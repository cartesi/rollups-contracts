// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Quorum} from "contracts/consensus/quorum/Quorum.sol";
import {IQuorum} from "contracts/consensus/quorum/IQuorum.sol";
import {IConsensus} from "contracts/consensus/IConsensus.sol";

import {TestBase} from "../../util/TestBase.sol";
import {LibAddressArray} from "../../util/LibAddressArray.sol";
import {LibTopic} from "../../util/LibTopic.sol";

import {Vm} from "forge-std/Vm.sol";

contract QuorumTest is TestBase {
    using LibAddressArray for address[];
    using LibTopic for address;
    using LibTopic for uint256;

    function testConstructor(
        uint8 numOfValidators,
        uint256 epochLength
    ) external {
        address[] memory validators = _generateAddresses(numOfValidators);

        IQuorum quorum = new Quorum(validators, epochLength);

        assertEq(quorum.numOfValidators(), numOfValidators);

        for (uint256 i; i < numOfValidators; ++i) {
            address validator = validators[i];
            uint256 id = quorum.validatorId(validator);
            assertEq(quorum.validatorById(id), validator);
            assertEq(id, i + 1);
        }
    }

    function testConstructorIgnoresDuplicates(uint256 epochLength) external {
        address[] memory validators = new address[](7);

        validators[0] = vm.addr(1);
        validators[1] = vm.addr(2);
        validators[2] = vm.addr(1);
        validators[3] = vm.addr(3);
        validators[4] = vm.addr(2);
        validators[5] = vm.addr(1);
        validators[6] = vm.addr(3);

        IQuorum quorum = new Quorum(validators, epochLength);

        assertEq(quorum.numOfValidators(), 3);

        for (uint256 i = 1; i <= 3; ++i) {
            assertEq(quorum.validatorId(vm.addr(i)), i);
            assertEq(quorum.validatorById(i), vm.addr(i));
        }
    }

    function testValidatorId(
        uint8 numOfValidators,
        address addr,
        uint256 epochLength
    ) external {
        address[] memory validators = _generateAddresses(numOfValidators);

        IQuorum quorum = new Quorum(validators, epochLength);

        uint256 id = quorum.validatorId(addr);

        if (validators.contains(addr)) {
            assertLe(1, id);
            assertLe(id, numOfValidators);
        } else {
            assertEq(id, 0);
        }
    }

    function testValidatorByIdZero(
        uint8 numOfValidators,
        uint256 epochLength
    ) external {
        IQuorum quorum = _deployQuorum(numOfValidators, epochLength);
        assertEq(quorum.validatorById(0), address(0));
    }

    function testValidatorByIdValid(
        uint8 numOfValidators,
        uint256 id,
        uint256 epochLength
    ) external {
        numOfValidators = uint8(bound(numOfValidators, 1, type(uint8).max));
        id = bound(id, 1, numOfValidators);
        IQuorum quorum = _deployQuorum(numOfValidators, epochLength);
        address validator = quorum.validatorById(id);
        assertEq(quorum.validatorId(validator), id);
    }

    function testValidatorByIdTooLarge(
        uint8 numOfValidators,
        uint256 id,
        uint256 epochLength
    ) external {
        id = bound(id, uint256(numOfValidators) + 1, type(uint256).max);
        IQuorum quorum = _deployQuorum(numOfValidators, epochLength);
        assertEq(quorum.validatorById(id), address(0));
    }

    function testSubmitClaimRevertsNotValidator(
        uint8 numOfValidators,
        uint256 epochLength,
        address caller,
        address appContract,
        bytes32 claim
    ) external {
        address[] memory validators = _generateAddresses(numOfValidators);
        epochLength = bound(epochLength, 1, _maxEpochLength());

        IQuorum quorum = new Quorum(validators, epochLength);

        vm.assume(!validators.contains(caller));

        quorum.sealEpoch(appContract);

        vm.expectRevert(IQuorum.CallerIsNotValidator.selector);

        vm.prank(caller);
        quorum.submitClaim(appContract, 0, claim);
    }

    function testNumOfValidatorsInFavorOf(
        uint8 numOfValidators,
        uint256 epochLength,
        address appContract,
        uint256 epochIndex,
        bytes32 claim
    ) external {
        IQuorum quorum = _deployQuorum(numOfValidators, epochLength);
        assertEq(
            quorum.numOfValidatorsInFavorOf(appContract, epochIndex, claim),
            0
        );
    }

    function testIsValidatorInFavorOf(
        uint8 numOfValidators,
        uint256 epochLength,
        address appContract,
        uint256 epochIndex,
        bytes32 claim,
        uint256 id
    ) external {
        IQuorum quorum = _deployQuorum(numOfValidators, epochLength);
        assertFalse(
            quorum.isValidatorInFavorOf(appContract, epochIndex, claim, id)
        );
    }

    function testSubmitClaim(
        uint8 numOfValidators,
        uint256 epochLength,
        address appContract,
        bytes32 claim
    ) external {
        numOfValidators = uint8(bound(numOfValidators, 1, 7));
        epochLength = bound(epochLength, 1, _maxEpochLength());
        IQuorum quorum = _deployQuorum(numOfValidators, epochLength);
        uint256 epochIndex = 0;
        _sealEpoch(quorum, appContract, epochIndex, 0);
        bool[] memory inFavorOf = new bool[](numOfValidators + 1);
        uint256 majority = 1 + numOfValidators / 2;
        for (uint256 id = 1; id <= majority; ++id) {
            _submitClaimAs(quorum, appContract, epochIndex, claim, id);
            inFavorOf[id] = true;
            _checkSubmitted(quorum, appContract, epochIndex, claim, inFavorOf);
        }
        assertEq(
            uint256(quorum.getEpochPhase(appContract, epochIndex)),
            uint256(IConsensus.Phase.SETTLED)
        );
        for (uint256 id = majority + 1; id <= numOfValidators; ++id) {
            address validator = quorum.validatorById(id);
            vm.expectRevert(
                abi.encodeWithSelector(
                    IConsensus.InvalidEpochPhase.selector,
                    appContract,
                    epochIndex
                )
            );
            vm.prank(validator);
            quorum.submitClaim(appContract, epochIndex, claim);
        }
    }

    /// @notice Tests the storage of votes in bitmap format
    /// @dev Each slot has 256 bits, one for each validator ID.
    /// The first bit is skipped because validator IDs start from 1.
    /// Therefore, validator ID 256 is the first to use a new slot.
    function testSubmitClaim256(
        uint256 epochLength,
        address appContract,
        bytes32 claim
    ) external {
        uint256 numOfValidators = 256;
        epochLength = bound(epochLength, 1, _maxEpochLength());

        IQuorum quorum = _deployQuorum(numOfValidators, epochLength);

        uint256 id = numOfValidators;

        uint256 epochIndex = 0;
        _sealEpoch(quorum, appContract, epochIndex, 0);
        _submitClaimAs(quorum, appContract, epochIndex, claim, id);

        assertTrue(
            quorum.isValidatorInFavorOf(appContract, epochIndex, claim, id)
        );
        assertEq(
            quorum.numOfValidatorsInFavorOf(appContract, epochIndex, claim),
            1
        );
    }

    // Internal functions
    // ------------------

    function _deployQuorum(
        uint256 numOfValidators,
        uint256 epochLength
    ) internal returns (IQuorum) {
        return new Quorum(_generateAddresses(numOfValidators), epochLength);
    }

    function _checkSubmitted(
        IQuorum quorum,
        address appContract,
        uint256 epochIndex,
        bytes32 claim,
        bool[] memory inFavorOf
    ) internal view {
        uint256 inFavorCount;
        uint256 numOfValidators = quorum.numOfValidators();

        for (uint256 id = 1; id <= numOfValidators; ++id) {
            assertEq(
                quorum.isValidatorInFavorOf(appContract, epochIndex, claim, id),
                inFavorOf[id]
            );
            if (inFavorOf[id]) ++inFavorCount;
        }

        assertEq(
            quorum.numOfValidatorsInFavorOf(appContract, epochIndex, claim),
            inFavorCount
        );
    }

    function _sealEpoch(
        IQuorum quorum,
        address appContract,
        uint256 epochIndex,
        uint256 lowerBound
    ) internal {
        uint256 upperBound = vm.getBlockNumber();

        vm.recordLogs();

        quorum.sealEpoch(appContract);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        uint256 numOfSealedEpochs;

        for (uint256 i; i < entries.length; ++i) {
            Vm.Log memory entry = entries[i];

            if (
                entry.emitter == address(quorum) &&
                entry.topics[0] == IConsensus.SealedEpoch.selector
            ) {
                IConsensus.BlockRange memory blockRange = abi.decode(
                    entry.data,
                    (IConsensus.BlockRange)
                );

                assertEq(entry.topics[1], appContract.asTopic());
                assertEq(entry.topics[2], epochIndex.asTopic());
                assertEq(blockRange.lowerBound, lowerBound);
                assertEq(blockRange.upperBound, upperBound);

                ++numOfSealedEpochs;
            }
        }

        assertEq(numOfSealedEpochs, 1);
    }

    function _submitClaimAs(
        IQuorum quorum,
        address appContract,
        uint256 epochIndex,
        bytes32 claim,
        uint256 id
    ) internal {
        address validator = quorum.validatorById(id);

        vm.recordLogs();

        vm.prank(validator);
        quorum.submitClaim(appContract, epochIndex, claim);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        uint256 numOfSubmittedClaims;
        uint256 numOfSettledEpochs;

        for (uint256 i; i < entries.length; ++i) {
            Vm.Log memory entry = entries[i];

            if (
                entry.emitter == address(quorum) &&
                entry.topics[0] == IConsensus.ClaimSubmission.selector
            ) {
                bytes32 eventClaim = abi.decode(entry.data, (bytes32));

                assertEq(entry.topics[1], appContract.asTopic());
                assertEq(entry.topics[2], epochIndex.asTopic());
                assertEq(entry.topics[3], validator.asTopic());
                assertEq(eventClaim, claim);

                ++numOfSubmittedClaims;
            }

            if (
                entry.emitter == address(quorum) &&
                entry.topics[0] == IConsensus.SettledEpoch.selector
            ) {
                bytes32 eventClaim = abi.decode(entry.data, (bytes32));

                assertEq(entry.topics[1], appContract.asTopic());
                assertEq(entry.topics[2], epochIndex.asTopic());
                assertEq(eventClaim, claim);

                ++numOfSettledEpochs;
            }
        }

        assertEq(numOfSubmittedClaims, 1);

        uint256 inFavorCount = quorum.numOfValidatorsInFavorOf(
            appContract,
            epochIndex,
            claim
        );
        uint256 numOfValidators = quorum.numOfValidators();

        if (inFavorCount == 1 + (numOfValidators / 2)) {
            assertEq(numOfSettledEpochs, 1);
        } else {
            assertEq(numOfSettledEpochs, 0);
        }

        assertEq(
            quorum.wasClaimSettled(appContract, claim),
            inFavorCount > (numOfValidators / 2)
        );
    }

    function _generateAddresses(
        uint256 n
    ) internal pure returns (address[] memory) {
        return LibAddressArray.generate(vm, n);
    }

    function _maxEpochLength() internal view returns (uint256) {
        return type(uint256).max - vm.getBlockNumber();
    }
}
