// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {InputRange} from "contracts/common/InputRange.sol";
import {Quorum} from "contracts/consensus/quorum/Quorum.sol";
import {IConsensus} from "contracts/consensus/IConsensus.sol";

import {TestBase} from "../../util/TestBase.sol";

import {Vm} from "forge-std/Vm.sol";

struct Claim {
    address dapp;
    InputRange inputRange;
    bytes32 epochHash;
}

library LibClaim {
    function numOfValidatorsInFavorOf(
        Quorum quorum,
        Claim calldata claim
    ) internal view returns (uint256) {
        return
            quorum.numOfValidatorsInFavorOf(
                claim.dapp,
                claim.inputRange,
                claim.epochHash
            );
    }

    function isValidatorInFavorOf(
        Quorum quorum,
        Claim calldata claim,
        uint256 id
    ) internal view returns (bool) {
        return
            quorum.isValidatorInFavorOf(
                claim.dapp,
                claim.inputRange,
                claim.epochHash,
                id
            );
    }

    function submitClaim(Quorum quorum, Claim calldata claim) internal {
        quorum.submitClaim(claim.dapp, claim.inputRange, claim.epochHash);
    }
}

contract QuorumTest is TestBase {
    using LibClaim for Quorum;

    function testConstructor(uint8 numOfValidators) external {
        address[] memory validators = _generateAddresses(numOfValidators);

        Quorum quorum = new Quorum(validators);

        assertEq(quorum.numOfValidators(), numOfValidators);

        for (uint256 i; i < numOfValidators; ++i) {
            address validator = validators[i];
            uint256 id = quorum.validatorId(validator);
            assertEq(quorum.validatorById(id), validator);
            assertEq(id, i + 1);
        }
    }

    function testConstructorIgnoresDuplicates() external {
        address[] memory validators = new address[](7);

        validators[0] = vm.addr(1);
        validators[1] = vm.addr(2);
        validators[2] = vm.addr(1);
        validators[3] = vm.addr(3);
        validators[4] = vm.addr(2);
        validators[5] = vm.addr(1);
        validators[6] = vm.addr(3);

        Quorum quorum = new Quorum(validators);

        assertEq(quorum.numOfValidators(), 3);

        for (uint256 i = 1; i <= 3; ++i) {
            assertEq(quorum.validatorId(vm.addr(i)), i);
            assertEq(quorum.validatorById(i), vm.addr(i));
        }
    }

    function testValidatorId(uint8 numOfValidators, address addr) external {
        address[] memory validators = _generateAddresses(numOfValidators);

        Quorum quorum = new Quorum(validators);

        uint256 id = quorum.validatorId(addr);

        if (_contains(validators, addr)) {
            assertLe(1, id);
            assertLe(id, numOfValidators);
        } else {
            assertEq(id, 0);
        }
    }

    function testValidatorById(uint8 numOfValidators, uint8 id) external {
        Quorum quorum = _deployQuorum(numOfValidators);

        address validator = quorum.validatorById(id);

        if (id >= 1 && id <= numOfValidators) {
            assertEq(quorum.validatorId(validator), id);
        } else {
            assertEq(validator, address(0));
        }
    }

    function testSubmitClaimRevertsNotValidator(
        uint8 numOfValidators,
        address caller,
        Claim calldata claim
    ) external {
        Quorum quorum = _deployQuorum(numOfValidators);

        vm.assume(quorum.validatorId(caller) == 0);

        vm.expectRevert("Quorum: caller is not validator");

        vm.prank(caller);
        quorum.submitClaim(claim);
    }

    function testNumOfValidatorsInFavorOf(
        uint8 numOfValidators,
        Claim calldata claim
    ) external {
        Quorum quorum = _deployQuorum(numOfValidators);
        assertEq(quorum.numOfValidatorsInFavorOf(claim), 0);
    }

    function testIsValidatorInFavorOf(
        uint8 numOfValidators,
        Claim calldata claim,
        uint256 id
    ) external {
        Quorum quorum = _deployQuorum(numOfValidators);
        assertFalse(quorum.isValidatorInFavorOf(claim, id));
    }

    function testSubmitClaim(
        uint8 numOfValidators,
        Claim calldata claim
    ) external {
        numOfValidators = uint8(bound(numOfValidators, 1, 7));
        Quorum quorum = _deployQuorum(numOfValidators);
        bool[] memory submitted = new bool[](numOfValidators + 1);
        for (uint256 id = 1; id <= numOfValidators; ++id) {
            _submitClaimAs(quorum, claim, id);
            submitted[id] = true;
            _checkSubmitted(quorum, claim, submitted);
        }
    }

    /// @notice Tests the storage of votes in bitmap format
    /// @dev Each slot has 256 bits, one for each validator ID.
    /// The first bit is skipped because validator IDs start from 1.
    /// Therefore, validator ID 256 is the first to use a new slot.
    function testSubmitClaim256(Claim calldata claim) external {
        uint256 numOfValidators = 256;

        Quorum quorum = _deployQuorum(numOfValidators);

        uint256 id = numOfValidators;

        _submitClaimAs(quorum, claim, id);

        assertTrue(quorum.isValidatorInFavorOf(claim, id));
        assertEq(quorum.numOfValidatorsInFavorOf(claim), 1);
    }

    // Internal functions
    // ------------------

    function _deployQuorum(uint256 numOfValidators) internal returns (Quorum) {
        return new Quorum(_generateAddresses(numOfValidators));
    }

    function _checkSubmitted(
        Quorum quorum,
        Claim calldata claim,
        bool[] memory submitted
    ) internal {
        uint256 inFavorCount;
        uint256 numOfValidators = quorum.numOfValidators();

        for (uint256 id = 1; id <= numOfValidators; ++id) {
            assertEq(quorum.isValidatorInFavorOf(claim, id), submitted[id]);
            if (submitted[id]) ++inFavorCount;
        }

        assertEq(quorum.numOfValidatorsInFavorOf(claim), inFavorCount);
    }

    function _submitClaimAs(
        Quorum quorum,
        Claim calldata claim,
        uint256 id
    ) internal {
        address validator = quorum.validatorById(id);

        vm.recordLogs();

        vm.prank(validator);
        quorum.submitClaim(claim);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        uint256 numOfSubmissions;
        uint256 numOfAcceptances;

        for (uint256 i; i < entries.length; ++i) {
            Vm.Log memory entry = entries[i];

            if (
                entry.emitter == address(quorum) &&
                entry.topics[0] == IConsensus.ClaimSubmission.selector
            ) {
                address submitter = address(uint160(uint256(entry.topics[1])));
                address dapp = address(uint160(uint256(entry.topics[2])));

                (InputRange memory inputRange, bytes32 epochHash) = abi.decode(
                    entry.data,
                    (InputRange, bytes32)
                );

                assertEq(submitter, validator);
                assertEq(dapp, claim.dapp);
                assertEq(inputRange.firstIndex, claim.inputRange.firstIndex);
                assertEq(inputRange.lastIndex, claim.inputRange.lastIndex);
                assertEq(epochHash, claim.epochHash);

                ++numOfSubmissions;
            }

            if (
                entry.emitter == address(quorum) &&
                entry.topics[0] == IConsensus.ClaimAcceptance.selector
            ) {
                address dapp = address(uint160(uint256(entry.topics[1])));

                (InputRange memory inputRange, bytes32 epochHash) = abi.decode(
                    entry.data,
                    (InputRange, bytes32)
                );

                assertEq(dapp, claim.dapp);
                assertEq(inputRange.firstIndex, claim.inputRange.firstIndex);
                assertEq(inputRange.lastIndex, claim.inputRange.lastIndex);
                assertEq(epochHash, claim.epochHash);

                ++numOfAcceptances;
            }
        }

        assertEq(numOfSubmissions, 1);

        uint256 inFavorCount = quorum.numOfValidatorsInFavorOf(claim);
        uint256 numOfValidators = quorum.numOfValidators();

        if (inFavorCount == 1 + (numOfValidators / 2)) {
            assertEq(numOfAcceptances, 1);
        } else {
            assertEq(numOfAcceptances, 0);
        }

        if (inFavorCount > (numOfValidators / 2)) {
            assertEq(
                quorum.getEpochHash(claim.dapp, claim.inputRange),
                claim.epochHash
            );
        }
    }
}
