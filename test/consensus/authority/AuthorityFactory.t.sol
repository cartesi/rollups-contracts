// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Authority Factory Test
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin-contracts-5.2.0/access/Ownable.sol";
import {Test} from "forge-std-1.9.6/src/Test.sol";
import {Vm} from "forge-std-1.9.6/src/Vm.sol";

import {IConsensus} from "src/consensus/IConsensus.sol";
import {AuthorityFactory} from "src/consensus/authority/AuthorityFactory.sol";
import {IAuthority} from "src/consensus/authority/IAuthority.sol";
import {IAuthorityFactory} from "src/consensus/authority/IAuthorityFactory.sol";

import {Claim} from "../../util/Claim.sol";
import {ConsensusTestUtils} from "../../util/ConsensusTestUtils.sol";
import {ERC165Test} from "../../util/ERC165Test.sol";
import {LibConsensus} from "../../util/LibConsensus.sol";
import {LibTopic} from "../../util/LibTopic.sol";
import {OwnableTest} from "../../util/OwnableTest.sol";

contract AuthorityFactoryTest is Test, ERC165Test, OwnableTest, ConsensusTestUtils {
    using LibConsensus for IAuthority;
    using LibTopic for address;

    AuthorityFactory _factory;
    bytes4[] _supportedInterfaces;

    function setUp() public {
        _factory = new AuthorityFactory();
        _supportedInterfaces.push(type(IConsensus).interfaceId);
        _supportedInterfaces.push(type(IAuthority).interfaceId);
        _registerSupportedInterfaces(_supportedInterfaces);
    }

    function testNewAuthority(
        address authorityOwner,
        uint256 epochLength,
        bytes4 interfaceId
    ) public {
        vm.recordLogs();

        try _factory.newAuthority(authorityOwner, epochLength) returns (
            IAuthority authority
        ) {
            Vm.Log[] memory logs = vm.getRecordedLogs();
            _testNewAuthoritySuccess(
                authorityOwner, epochLength, interfaceId, authority, logs
            );
        } catch (bytes memory error) {
            _testNewAuthorityFailure(authorityOwner, epochLength, error);
            return;
        }
    }

    function testNewAuthorityDeterministic(
        address authorityOwner,
        uint256 epochLength,
        bytes4 interfaceId,
        bytes32 salt
    ) public {
        address precalculatedAddress =
            _factory.calculateAuthorityAddress(authorityOwner, epochLength, salt);

        vm.recordLogs();

        try _factory.newAuthority(authorityOwner, epochLength, salt) returns (
            IAuthority authority
        ) {
            Vm.Log[] memory logs = vm.getRecordedLogs();

            assertEq(
                precalculatedAddress,
                address(authority),
                "calculateAuthorityAddress(...) != newAuthority(...)"
            );

            _testNewAuthoritySuccess(
                authorityOwner, epochLength, interfaceId, authority, logs
            );
        } catch (bytes memory error) {
            _testNewAuthorityFailure(authorityOwner, epochLength, error);
            return;
        }

        assertEq(
            _factory.calculateAuthorityAddress(authorityOwner, epochLength, salt),
            precalculatedAddress,
            "calculateAuthorityAddress(...) is not a pure function"
        );

        // Cannot deploy an application with the same salt twice
        try _factory.newAuthority(authorityOwner, epochLength, salt) {
            revert("second deterministic deployment did not revert");
        } catch (bytes memory error) {
            assertEq(
                error,
                new bytes(0),
                "second deterministic deployment did not revert with empty error data"
            );
        }
    }

    function testRenounceOwnership(address authorityOwner, uint256 epochLength) external {
        IAuthority authority = _newAuthority(authorityOwner, epochLength);
        _testRenounceOwnership(authority);
    }

    function testUnauthorizedAccount(address authorityOwner, uint256 epochLength)
        external
    {
        IAuthority authority = _newAuthority(authorityOwner, epochLength);
        _testUnauthorizedAccount(authority);
    }

    function testInvalidOwner(address authorityOwner, uint256 epochLength) external {
        IAuthority authority = _newAuthority(authorityOwner, epochLength);
        _testInvalidOwner(authority);
    }

    function testTransferOwnership(address authorityOwner, uint256 epochLength) external {
        IAuthority authority = _newAuthority(authorityOwner, epochLength);
        _testTransferOwnership(authority);
    }

    function testSubmitClaimRevertsOwnableUnauthorizedAccount(
        address authorityOwner,
        uint256 epochLength,
        Claim memory claim
    ) external {
        IAuthority authority = _newAuthority(authorityOwner, epochLength);

        claim.appContract = _newActiveAppMock();

        claim.lastProcessedBlockNumber = _randomFutureEpochFinalBlockNumber(epochLength);
        vm.roll(_randomUintGt(claim.lastProcessedBlockNumber));

        address nonAuthorityOwner = _randomAddressDifferentFromZeroAnd(authorityOwner);

        vm.expectRevert(_encodeOwnableUnauthorizedAccount(nonAuthorityOwner));
        vm.prank(nonAuthorityOwner);
        authority.submitClaim(claim);
    }

    function testSubmitClaimRevertsNotEpochFinalBlock(
        address authorityOwner,
        uint256 epochLength,
        Claim memory claim
    ) external {
        uint256 lastProcessedBlockNumber = _randomNonEpochFinalBlock(epochLength);

        IAuthority authority = _newAuthority(authorityOwner, epochLength);

        claim.appContract = _newActiveAppMock();

        claim.lastProcessedBlockNumber = lastProcessedBlockNumber;
        vm.roll(_randomUintGt(claim.lastProcessedBlockNumber));

        vm.expectRevert(_encodeNotEpochFinalBlock(lastProcessedBlockNumber, epochLength));
        vm.prank(authorityOwner);
        authority.submitClaim(claim);
    }

    function testSubmitClaimRevertNotPastBlock(
        address authorityOwner,
        uint256 epochLength,
        Claim memory claim
    ) external {
        IAuthority authority = _newAuthority(authorityOwner, epochLength);

        claim.appContract = _newActiveAppMock();

        // Adjust the lastProcessedBlockNumber but do not roll past it.
        claim.lastProcessedBlockNumber = _randomFutureEpochFinalBlockNumber(epochLength);

        vm.expectRevert(_encodeNotPastBlock(claim.lastProcessedBlockNumber));
        vm.prank(authorityOwner);
        authority.submitClaim(claim);
    }

    function testSubmitClaimRevertApplicationNotDeployed(
        address authorityOwner,
        uint256 epochLength,
        Claim memory claim
    ) external {
        IAuthority authority = _newAuthority(authorityOwner, epochLength);

        // We use a random account with no code as app contract
        claim.appContract = _randomAccountWithNoCode();

        claim.lastProcessedBlockNumber = _randomFutureEpochFinalBlockNumber(epochLength);
        vm.roll(_randomUintGt(claim.lastProcessedBlockNumber));

        vm.expectRevert(_encodeApplicationNotDeployed(claim.appContract));
        vm.prank(authorityOwner);
        authority.submitClaim(claim);
    }

    function testSubmitClaimRevertApplicationReverted(
        address authorityOwner,
        uint256 epochLength,
        Claim memory claim,
        bytes memory error
    ) external {
        IAuthority authority = _newAuthority(authorityOwner, epochLength);

        // We make isForeclosed() revert with an error
        claim.appContract = _newAppMockReverts(error);

        claim.lastProcessedBlockNumber = _randomFutureEpochFinalBlockNumber(epochLength);
        vm.roll(_randomUintGt(claim.lastProcessedBlockNumber));

        vm.expectRevert(_encodeApplicationReverted(claim.appContract, error));
        vm.prank(authorityOwner);
        authority.submitClaim(claim);
    }

    function testSubmitClaimRevertApplicationReturnIllSizedReturnData(
        address authorityOwner,
        uint256 epochLength,
        Claim memory claim,
        bytes memory data
    ) external {
        // We make isForeclosed() return ill-sized data
        vm.assume(data.length != 32);

        IAuthority authority = _newAuthority(authorityOwner, epochLength);

        claim.appContract = _newAppMockReturns(data);

        claim.lastProcessedBlockNumber = _randomFutureEpochFinalBlockNumber(epochLength);
        vm.roll(_randomUintGt(claim.lastProcessedBlockNumber));

        vm.expectRevert(_encodeIllformedApplicationReturnData(claim.appContract, data));
        vm.prank(authorityOwner);
        authority.submitClaim(claim);
    }

    function testSubmitClaimRevertApplicationReturnIllFormedReturnData(
        address authorityOwner,
        uint256 epochLength,
        Claim memory claim,
        uint256 returnValue
    ) external {
        // We make isForeclosed() return an invalid boolean (neither 0 or 1)
        vm.assume(returnValue > 1);

        IAuthority authority = _newAuthority(authorityOwner, epochLength);

        bytes memory data = abi.encode(returnValue);
        claim.appContract = _newAppMockReturns(data);

        claim.lastProcessedBlockNumber = _randomFutureEpochFinalBlockNumber(epochLength);
        vm.roll(_randomUintGt(claim.lastProcessedBlockNumber));

        vm.expectRevert(_encodeIllformedApplicationReturnData(claim.appContract, data));
        vm.prank(authorityOwner);
        authority.submitClaim(claim);
    }

    function testSubmitClaimRevertApplicationForeclosed(
        address authorityOwner,
        uint256 epochLength,
        Claim memory claim
    ) external {
        IAuthority authority = _newAuthority(authorityOwner, epochLength);

        // We make isForeclosed() return true
        claim.appContract = _newForeclosedAppMock();

        claim.lastProcessedBlockNumber = _randomFutureEpochFinalBlockNumber(epochLength);
        vm.roll(_randomUintGt(claim.lastProcessedBlockNumber));

        vm.expectRevert(_encodeApplicationForeclosed(claim.appContract));
        vm.prank(authorityOwner);
        authority.submitClaim(claim);
    }

    function testSubmitClaim(
        address authorityOwner,
        uint256 epochLength,
        Claim memory claim
    ) external {
        IAuthority authority = _newAuthority(authorityOwner, epochLength);

        claim.appContract = _newActiveAppMock();

        claim.lastProcessedBlockNumber = _randomFutureEpochFinalBlockNumber(epochLength);
        vm.roll(_randomUintGt(claim.lastProcessedBlockNumber));

        uint256 totalNumOfSubmittedClaimsBefore = authority.getNumberOfSubmittedClaims();
        uint256 totalNumOfAcceptedClaimsBefore = authority.getNumberOfAcceptedClaims();

        vm.recordLogs();

        vm.prank(authorityOwner);
        authority.submitClaim(claim);

        Vm.Log[] memory logs = vm.getRecordedLogs();

        uint256 numOfClaimSubmittedEvents;
        uint256 numOfClaimAcceptedEvents;

        for (uint256 j; j < logs.length; ++j) {
            Vm.Log memory log = logs[j];
            if (log.emitter == address(authority)) {
                assertGe(log.topics.length, 1, "unexpected annonymous event");
                bytes32 topic0 = log.topics[0];
                if (topic0 == IConsensus.ClaimSubmitted.selector) {
                    (uint256 arg0, bytes32 arg1) =
                        abi.decode(log.data, (uint256, bytes32));
                    assertEq(log.topics[1], authorityOwner.asTopic());
                    assertEq(log.topics[2], claim.appContract.asTopic());
                    assertEq(arg0, claim.lastProcessedBlockNumber);
                    assertEq(arg1, claim.outputsMerkleRoot);
                    ++numOfClaimSubmittedEvents;
                } else if (topic0 == IConsensus.ClaimAccepted.selector) {
                    (uint256 arg0, bytes32 arg1) =
                        abi.decode(log.data, (uint256, bytes32));
                    assertEq(log.topics[1], claim.appContract.asTopic());
                    assertEq(arg0, claim.lastProcessedBlockNumber);
                    assertEq(arg1, claim.outputsMerkleRoot);
                    ++numOfClaimAcceptedEvents;
                } else {
                    revert("unexpected event selector");
                }
            } else {
                revert("unexpected log emitter");
            }
        }

        assertEq(numOfClaimSubmittedEvents, 1, "expected 1 ClaimSubmitted event");
        assertEq(numOfClaimAcceptedEvents, 1, "expected 1 ClaimAccepted event");

        assertTrue(
            authority.isOutputsMerkleRootValid(
                claim.appContract, claim.outputsMerkleRoot
            ),
            "Once a claim is accepted, the outputs Merkle root is valid"
        );

        assertEq(
            authority.getNumberOfSubmittedClaims(),
            totalNumOfSubmittedClaimsBefore + numOfClaimSubmittedEvents,
            "Total number of submitted claims should be increased by number of events"
        );

        assertEq(
            authority.getNumberOfAcceptedClaims(),
            totalNumOfAcceptedClaimsBefore + numOfClaimAcceptedEvents,
            "Total number of accepted claims should be increased by number of events"
        );

        vm.expectRevert(
            _encodeNotFirstClaim(claim.appContract, claim.lastProcessedBlockNumber)
        );
        vm.prank(authorityOwner);
        authority.submitClaim(
            claim.appContract, claim.lastProcessedBlockNumber, bytes32(vm.randomUint())
        );
    }

    function _testNewAuthoritySuccess(
        address authorityOwner,
        uint256 epochLength,
        bytes4 interfaceId,
        IAuthority authority,
        Vm.Log[] memory logs
    ) internal {
        uint256 numOfAuthorityCreated;
        uint256 numOfOwnershipTransferred;

        for (uint256 i; i < logs.length; ++i) {
            Vm.Log memory log = logs[i];
            if (log.emitter == address(_factory)) {
                bytes32 topic0 = log.topics[0];
                if (topic0 == IAuthorityFactory.AuthorityCreated.selector) {
                    ++numOfAuthorityCreated;
                    address authorityAddress = abi.decode(log.data, (address));
                    assertEq(address(authority), authorityAddress);
                } else {
                    revert("unexpected log topic #0");
                }
            } else if (log.emitter == address(authority)) {
                bytes32 topic0 = log.topics[0];
                if (topic0 == Ownable.OwnershipTransferred.selector) {
                    ++numOfOwnershipTransferred;
                    assertEq(log.topics[1], address(0).asTopic());
                    assertEq(log.topics[2], authorityOwner.asTopic());
                } else {
                    revert("unexpected log topic #0");
                }
            } else {
                revert("unexpected log");
            }
        }

        assertEq(numOfAuthorityCreated, 1, "number of AuthorityCreated events");
        assertEq(numOfOwnershipTransferred, 1, "number of OwnershipTransferred events");

        assertEq(authority.owner(), authorityOwner, "owner() == authorityOwner");
        assertNotEq(authorityOwner, address(0), "owner() != address(0)");

        assertEq(
            authority.getEpochLength(), epochLength, "getEpochLength() == epochLength"
        );
        assertGt(epochLength, 0, "getEpochLength() > 0");

        // We check that initially all outputs Merkle roots are invalid.
        assertFalse(
            authority.isOutputsMerkleRootValid(
                vm.randomAddress(), bytes32(vm.randomUint())
            ),
            "initially, isOutputsMerkleRootValid(...) == false"
        );

        // Also, initially, no `ClaimSubmitted` or `ClaimAccepted` were emitted.
        assertEq(
            authority.getNumberOfSubmittedClaims(),
            0,
            "initially, getNumberOfSubmittedClaims() == 0"
        );
        assertEq(
            authority.getNumberOfAcceptedClaims(),
            0,
            "initially, getNumberOfAcceptedClaims() == 0"
        );

        // Test ERC-165 interface
        _testSupportsInterface(authority, interfaceId);
    }

    function _testNewAuthorityFailure(
        address authorityOwner,
        uint256 epochLength,
        bytes memory error
    ) internal pure {
        assertGe(error.length, 4, "Error data too short (no 4-byte selector)");

        // forge-lint: disable-next-line(unsafe-typecast)
        bytes4 errorSelector = bytes4(error);
        bytes memory errorArgs = new bytes(error.length - 4);

        for (uint256 i; i < errorArgs.length; ++i) {
            errorArgs[i] = error[i + 4];
        }

        if (errorSelector == Ownable.OwnableInvalidOwner.selector) {
            address owner = abi.decode(errorArgs, (address));
            assertEq(owner, authorityOwner, "OwnableInvalidOwner.owner != owner");
            assertEq(owner, address(0), "OwnableInvalidOwner.owner != address(0)");
        } else if (errorSelector == bytes4(keccak256("Error(string)"))) {
            string memory message = abi.decode(errorArgs, (string));
            if (keccak256(bytes(message)) == keccak256("epoch length must not be zero")) {
                assertEq(epochLength, 0, "expected epoch length to be zero");
            } else {
                revert("Unexpected error message");
            }
        } else {
            revert("Unexpected error");
        }
    }

    function _newAuthority(address authorityOwner, uint256 epochLength)
        internal
        returns (IAuthority)
    {
        if (vm.randomBool()) {
            vm.assumeNoRevert();
            return _factory.newAuthority(authorityOwner, epochLength);
        } else {
            bytes32 salt = bytes32(vm.randomUint());
            vm.assumeNoRevert();
            return _factory.newAuthority(authorityOwner, epochLength, salt);
        }
    }
}
