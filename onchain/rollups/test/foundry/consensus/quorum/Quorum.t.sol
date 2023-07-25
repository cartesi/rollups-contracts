// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {stdError} from "forge-std/StdError.sol";

import {Quorum} from "contracts/consensus/quorum/Quorum.sol";
import {IHistory} from "contracts/history/IHistory.sol";

import {TestBase} from "../../util/TestBase.sol";

contract HistoryMock is IHistory {
    bytes[] internal claims;

    function submitClaim(bytes calldata _claim) external override {
        claims.push(_claim);
    }

    function migrateToConsensus(address) external override {}

    function getClaim(
        address,
        bytes calldata
    ) external view returns (bytes32, uint256, uint256) {}

    function numOfClaims() external view returns (uint256) {
        return claims.length;
    }

    function claim(uint256 _index) external view returns (bytes memory) {
        return claims[_index];
    }
}

contract QuorumTest is TestBase {
    HistoryMock history;

    // External functions
    // ------------------

    function setUp() external {
        history = new HistoryMock();
    }

    function testHistory() external {
        assertEq(history.numOfClaims(), 0);
    }

    function testConstructorRevertsLengthMismatch(
        uint8 numOfValidators,
        uint8 numOfShares
    ) external {
        vm.assume(numOfValidators != numOfShares);
        vm.expectRevert("PaymentSplitter: payees and shares length mismatch");
        deployQuorumUnchecked(numOfValidators, numOfShares);
    }

    function testConstructorRevertsNoPayees() external {
        vm.expectRevert("PaymentSplitter: no payees");
        deployQuorumUnchecked(0);
    }

    function testConstructorRevertsAccountIsZeroAddress(
        uint8 numOfValidators
    ) external {
        vm.assume(numOfValidators >= 1);
        vm.expectRevert("PaymentSplitter: account is the zero address");
        new Quorum(
            new address[](numOfValidators),
            generateArithmeticSequence(numOfValidators),
            history
        );
    }

    function testConstructorRevertsSharesAreZero(
        uint8 numOfValidators
    ) external {
        vm.assume(numOfValidators >= 1);
        vm.expectRevert("PaymentSplitter: shares are 0");
        new Quorum(
            generateAddresses(numOfValidators),
            new uint256[](numOfValidators),
            history
        );
    }

    function testConstructorRevertsAccountAlreadyHasShares(
        uint8 numOfValidators
    ) external {
        vm.assume(numOfValidators >= 2);
        vm.expectRevert("PaymentSplitter: account already has shares");
        new Quorum(
            generateConstantArray(numOfValidators, vm.addr(1)),
            generateArithmeticSequence(numOfValidators),
            history
        );
    }

    function testConstructorRevertsTotalSharesOverflow(
        uint8 numOfValidators
    ) external {
        vm.assume(numOfValidators >= 2);
        vm.expectRevert(stdError.arithmeticError);
        new Quorum(
            generateAddresses(numOfValidators),
            generateConstantArray(numOfValidators, type(uint256).max),
            history
        );
    }

    function testConstructor(uint8 numOfValidators) external {
        vm.assume(numOfValidators >= 1);

        address[] memory validators = generateAddresses(numOfValidators);
        uint256[] memory shares = generateArithmeticSequence(numOfValidators);

        Quorum quorum = new Quorum(validators, shares, history);

        assertEq(quorum.numOfValidators(), numOfValidators);
        assertEq(quorum.validators(), validators);
        assertEq(quorum.totalShares(), sum(shares));
        assertEq(address(quorum.getHistory()), address(history));

        for (uint256 i; i < numOfValidators; ++i) {
            address validator = validators[i];
            uint256 id = quorum.validatorId(validator);

            assertEq(quorum.payee(i), validator);
            assertEq(quorum.shares(validator), shares[i]);
            assertEq(quorum.validatorById(id), validator);
        }
    }

    function testZeroValidatorId(uint8 numOfValidators, address addr) external {
        Quorum quorum = deployQuorum(numOfValidators);
        assertEq(
            contains(quorum.validators(), addr),
            quorum.validatorId(addr) != 0
        );
    }

    function testValidatorByInvalidId(
        uint8 numOfValidators,
        uint256 validatorId
    ) external {
        vm.assume(validatorId < 1 || validatorId > numOfValidators);
        Quorum quorum = deployQuorum(numOfValidators);
        assertEq(quorum.validatorById(validatorId), address(0));
    }

    function testSubmitClaimRevertsNotValidator(
        uint8 numOfValidators,
        address caller,
        bytes calldata claim
    ) external {
        Quorum quorum = deployQuorum(numOfValidators);
        vm.assume(quorum.validatorId(caller) == 0);
        vm.prank(caller);
        vm.expectRevert("Quorum: sender is not validator");
        quorum.submitClaim(claim);
    }

    function testNumOfValidatorsInFavorOfClaim(
        uint8 numOfValidators,
        bytes calldata claim
    ) external {
        Quorum quorum = deployQuorum(numOfValidators);
        assertEq(quorum.numOfValidatorsInFavorOf(claim), 0);
    }

    function testIsValidatorInFavorOf(
        uint8 numOfValidators,
        uint256 validatorId,
        bytes memory claim
    ) external {
        Quorum quorum = deployQuorum(numOfValidators);
        assertFalse(quorum.isValidatorInFavorOf(validatorId, claim));
    }

    function testValidatorsInFavorOfClaim(
        uint8 numOfValidators,
        bytes calldata claim
    ) external {
        Quorum quorum = deployQuorum(numOfValidators);
        assertEq(quorum.validatorsInFavorOf(claim), new address[](0));
    }

    function testSubmitClaim(bytes memory claim) external {
        Quorum quorum = deployQuorum(3);
        bool[] memory submitLog = new bool[](4);

        submitClaim(quorum, claim, submitLog, 1);
        assertEq(history.numOfClaims(), 0);

        // resubmitting makes no difference
        submitClaim(quorum, claim, submitLog, 1);
        assertEq(history.numOfClaims(), 0);

        submitClaim(quorum, claim, submitLog, 2);
        assertEq(history.numOfClaims(), 1);
        assertEq(history.claim(0), claim);

        submitClaim(quorum, claim, submitLog, 3);
        assertEq(history.numOfClaims(), 1);
    }

    // Internal functions
    // ------------------

    function deployQuorum(uint256 numOfValidators) internal returns (Quorum) {
        vm.assume(numOfValidators >= 1);
        return deployQuorumUnchecked(numOfValidators, numOfValidators);
    }

    function deployQuorumUnchecked(
        uint256 numOfValidators
    ) internal returns (Quorum) {
        return deployQuorumUnchecked(numOfValidators, numOfValidators);
    }

    function deployQuorumUnchecked(
        uint256 numOfValidators,
        uint256 numOfShares
    ) internal returns (Quorum) {
        return
            new Quorum(
                generateAddresses(numOfValidators),
                generateArithmeticSequence(numOfShares),
                history
            );
    }

    function submitClaim(
        Quorum quorum,
        bytes memory claim,
        bool[] memory submitLog,
        uint256 validatorId
    ) internal {
        vm.prank(quorum.validatorById(validatorId));
        quorum.submitClaim(claim);

        submitLog[validatorId] = true;

        address[] memory validatorsInFavor = quorum.validatorsInFavorOf(claim);
        uint256 numOfValidatorsInFavorOfClaim;

        for (uint256 id; id < submitLog.length; ++id) {
            bool inFavor = submitLog[id];
            assertEq(quorum.isValidatorInFavorOf(id, claim), inFavor);
            if (inFavor) ++numOfValidatorsInFavorOfClaim;
        }

        assertEq(
            quorum.numOfValidatorsInFavorOf(claim),
            numOfValidatorsInFavorOfClaim
        );

        assertEq(validatorsInFavor.length, numOfValidatorsInFavorOfClaim);

        bool[] memory visited = new bool[](submitLog.length);

        for (uint256 i; i < validatorsInFavor.length; ++i) {
            uint256 id = quorum.validatorId(validatorsInFavor[i]);
            assertFalse(visited[id]);
            assertTrue(submitLog[id]);
            visited[id] = true;
        }
    }
}
