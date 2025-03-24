// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {IERC165} from "@openzeppelin-contracts-5.2.0/utils/introspection/IERC165.sol";

import {Quorum} from "src/consensus/quorum/Quorum.sol";
import {IQuorum} from "src/consensus/quorum/IQuorum.sol";
import {IConsensus} from "src/consensus/IConsensus.sol";

import {ERC165Test} from "../../util/ERC165Test.sol";
import {LibAddressArray} from "../../util/LibAddressArray.sol";
import {LibTopic} from "../../util/LibTopic.sol";

import {Test} from "forge-std-1.9.6/Test.sol";
import {Vm} from "forge-std-1.9.6/Vm.sol";

struct Claim {
    address appContract;
    uint256 lastProcessedBlockNumber;
    bytes32 outputHashesRootHash;
}

library LibQuorum {
    function numOfValidatorsInFavorOf(IQuorum quorum, Claim calldata claim)
        internal
        view
        returns (uint256)
    {
        return quorum.numOfValidatorsInFavorOf(
            claim.appContract, claim.lastProcessedBlockNumber, claim.outputHashesRootHash
        );
    }

    function isValidatorInFavorOf(IQuorum quorum, Claim calldata claim, uint256 id)
        internal
        view
        returns (bool)
    {
        return quorum.isValidatorInFavorOf(
            claim.appContract,
            claim.lastProcessedBlockNumber,
            claim.outputHashesRootHash,
            id
        );
    }

    function submitClaim(IQuorum quorum, Claim calldata claim) internal {
        quorum.submitClaim(
            claim.appContract, claim.lastProcessedBlockNumber, claim.outputHashesRootHash
        );
    }

    function isOutputsMerkleRootValid(IQuorum quorum, Claim calldata claim)
        internal
        view
        returns (bool)
    {
        return
            quorum.isOutputsMerkleRootValid(claim.appContract, claim.outputHashesRootHash);
    }
}

contract QuorumTest is Test, ERC165Test {
    using LibQuorum for IQuorum;
    using LibAddressArray for address[];
    using LibAddressArray for Vm;
    using LibTopic for address;

    IQuorum _quorum;

    function setUp() external {
        _quorum = new Quorum(vm.addrs(3), 1);
    }

    /// @inheritdoc ERC165Test
    function _getERC165Contract() internal view override returns (IERC165) {
        return _quorum;
    }

    /// @inheritdoc ERC165Test
    function _getSupportedInterfaces() internal pure override returns (bytes4[] memory) {
        bytes4[] memory ifaces = new bytes4[](3);
        ifaces[0] = type(IERC165).interfaceId;
        ifaces[1] = type(IConsensus).interfaceId;
        ifaces[2] = type(IQuorum).interfaceId;
        return ifaces;
    }

    function testConstructor(uint8 numOfValidators, uint256 epochLength) external {
        vm.assume(epochLength > 0);

        address[] memory validators = vm.addrs(numOfValidators);

        IQuorum quorum = new Quorum(validators, epochLength);

        assertEq(quorum.numOfValidators(), numOfValidators);
        assertEq(quorum.getEpochLength(), epochLength);

        for (uint256 i; i < numOfValidators; ++i) {
            address validator = validators[i];
            uint256 id = quorum.validatorId(validator);
            assertEq(quorum.validatorById(id), validator);
            assertEq(id, i + 1);
        }
    }

    function testRevertsEpochLengthZero(uint8 numOfValidators) external {
        vm.expectRevert("epoch length must not be zero");
        new Quorum(vm.addrs(numOfValidators), 0);
    }

    function testConstructorIgnoresDuplicates(uint256 epochLength) external {
        vm.assume(epochLength > 0);

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

    function testValidatorId(uint8 numOfValidators, address addr, uint256 epochLength)
        external
    {
        vm.assume(epochLength > 0);

        address[] memory validators = vm.addrs(numOfValidators);

        IQuorum quorum = new Quorum(validators, epochLength);

        uint256 id = quorum.validatorId(addr);

        if (validators.contains(addr)) {
            assertLe(1, id);
            assertLe(id, numOfValidators);
        } else {
            assertEq(id, 0);
        }
    }

    function testValidatorByIdZero(uint8 numOfValidators, uint256 epochLength) external {
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
        Claim calldata claim
    ) external {
        vm.assume(epochLength > 0);

        address[] memory validators = vm.addrs(numOfValidators);

        IQuorum quorum = new Quorum(validators, epochLength);

        vm.assume(!validators.contains(caller));

        vm.expectRevert("Quorum: caller is not validator");

        vm.prank(caller);
        quorum.submitClaim(claim);
    }

    function testNumOfValidatorsInFavorOf(
        uint8 numOfValidators,
        uint256 epochLength,
        Claim calldata claim
    ) external {
        IQuorum quorum = _deployQuorum(numOfValidators, epochLength);
        assertEq(quorum.numOfValidatorsInFavorOf(claim), 0);
    }

    function testIsValidatorInFavorOf(
        uint8 numOfValidators,
        uint256 epochLength,
        Claim calldata claim,
        uint256 id
    ) external {
        IQuorum quorum = _deployQuorum(numOfValidators, epochLength);
        assertFalse(quorum.isValidatorInFavorOf(claim, id));
    }

    function testSubmitClaim(
        uint8 numOfValidators,
        uint256 epochLength,
        Claim calldata claim
    ) external {
        numOfValidators = uint8(bound(numOfValidators, 1, 7));
        IQuorum quorum = _deployQuorum(numOfValidators, epochLength);
        bool[] memory inFavorOf = new bool[](numOfValidators + 1);
        for (uint256 id = 1; id <= numOfValidators; ++id) {
            _submitClaimAs(quorum, claim, id);
            inFavorOf[id] = true;
            _checkSubmitted(quorum, claim, inFavorOf);
        }
    }

    /// @notice Tests the storage of votes in bitmap format
    /// @dev Each slot has 256 bits, one for each validator ID.
    /// The first bit is skipped because validator IDs start from 1.
    /// Therefore, validator ID 256 is the first to use a new slot.
    function testSubmitClaim256(Claim calldata claim, uint256 epochLength) external {
        uint256 numOfValidators = 256;

        IQuorum quorum = _deployQuorum(numOfValidators, epochLength);

        uint256 id = numOfValidators;

        _submitClaimAs(quorum, claim, id);

        assertTrue(quorum.isValidatorInFavorOf(claim, id));
        assertEq(quorum.numOfValidatorsInFavorOf(claim), 1);
    }

    // Internal functions
    // ------------------

    function _deployQuorum(uint256 numOfValidators, uint256 epochLength)
        internal
        returns (IQuorum)
    {
        vm.assume(epochLength > 0);
        return new Quorum(vm.addrs(numOfValidators), epochLength);
    }

    function _checkSubmitted(
        IQuorum quorum,
        Claim calldata claim,
        bool[] memory inFavorOf
    ) internal view {
        uint256 inFavorCount;
        uint256 numOfValidators = quorum.numOfValidators();

        for (uint256 id = 1; id <= numOfValidators; ++id) {
            assertEq(quorum.isValidatorInFavorOf(claim, id), inFavorOf[id]);
            if (inFavorOf[id]) ++inFavorCount;
        }

        assertEq(quorum.numOfValidatorsInFavorOf(claim), inFavorCount);
    }

    function _submitClaimAs(IQuorum quorum, Claim calldata claim, uint256 id) internal {
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
                entry.emitter == address(quorum)
                    && entry.topics[0] == IConsensus.ClaimSubmitted.selector
            ) {
                (uint256 lastProcessedBlockNumber, bytes32 outputHashesRootHash) =
                    abi.decode(entry.data, (uint256, bytes32));

                assertEq(entry.topics[1], validator.asTopic());
                assertEq(entry.topics[2], claim.appContract.asTopic());
                assertEq(lastProcessedBlockNumber, claim.lastProcessedBlockNumber);
                assertEq(outputHashesRootHash, claim.outputHashesRootHash);

                ++numOfSubmissions;
            }

            if (
                entry.emitter == address(quorum)
                    && entry.topics[0] == IConsensus.ClaimAccepted.selector
            ) {
                (uint256 lastProcessedBlockNumber, bytes32 outputHashesRootHash) =
                    abi.decode(entry.data, (uint256, bytes32));

                assertEq(entry.topics[1], claim.appContract.asTopic());
                assertEq(lastProcessedBlockNumber, claim.lastProcessedBlockNumber);
                assertEq(outputHashesRootHash, claim.outputHashesRootHash);

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

        assertEq(
            quorum.isOutputsMerkleRootValid(claim), inFavorCount > (numOfValidators / 2)
        );
    }
}
