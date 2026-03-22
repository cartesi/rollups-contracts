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
import {LibAddressArray} from "../../util/LibAddressArray.sol";
import {LibBytes} from "../../util/LibBytes.sol";
import {LibClaim} from "../../util/LibClaim.sol";
import {LibConsensus} from "../../util/LibConsensus.sol";
import {LibTopic} from "../../util/LibTopic.sol";
import {LibUint256Array} from "../../util/LibUint256Array.sol";
import {OwnableTest} from "../../util/OwnableTest.sol";
import {VersionGetterTestUtils} from "../../util/VersionGetterTestUtils.sol";

contract AuthorityFactoryTest is
    Test,
    ERC165Test,
    OwnableTest,
    ConsensusTestUtils,
    VersionGetterTestUtils
{
    using LibUint256Array for uint256[];
    using LibConsensus for IAuthority;
    using LibAddressArray for Vm;
    using LibTopic for address;
    using LibClaim for Claim;
    using LibBytes for bytes;

    AuthorityFactory _factory;
    bytes4[] _supportedInterfaces;

    function setUp() public {
        _factory = new AuthorityFactory();
        _supportedInterfaces.push(type(IConsensus).interfaceId);
        _supportedInterfaces.push(type(IAuthority).interfaceId);
        _registerSupportedInterfaces(_supportedInterfaces);
    }

    function testVersion() external view {
        _testVersion(_factory);
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
        } catch Error(string memory message) {
            _testNewAuthorityFailure(epochLength, message);
            return;
        } catch (bytes memory error) {
            _testNewAuthorityFailure(authorityOwner, error);
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
        } catch Error(string memory message) {
            _testNewAuthorityFailure(epochLength, message);
            return;
        } catch (bytes memory error) {
            _testNewAuthorityFailure(authorityOwner, error);
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

    function testRenounceOwnership(
        address authorityOwner,
        uint256 epochLength,
        bool nonDeterministicDeployment
    ) external {
        IAuthority authority = _newAuthority(
            authorityOwner, epochLength, nonDeterministicDeployment
        );
        _testRenounceOwnership(authority);
    }

    function testUnauthorizedAccount(
        address authorityOwner,
        uint256 epochLength,
        bool nonDeterministicDeployment
    ) external {
        IAuthority authority = _newAuthority(
            authorityOwner, epochLength, nonDeterministicDeployment
        );
        _testUnauthorizedAccount(authority);
    }

    function testInvalidOwner(
        address authorityOwner,
        uint256 epochLength,
        bool nonDeterministicDeployment
    ) external {
        IAuthority authority = _newAuthority(
            authorityOwner, epochLength, nonDeterministicDeployment
        );
        _testInvalidOwner(authority);
    }

    function testTransferOwnership(
        address authorityOwner,
        uint256 epochLength,
        bool nonDeterministicDeployment
    ) external {
        IAuthority authority = _newAuthority(
            authorityOwner, epochLength, nonDeterministicDeployment
        );
        _testTransferOwnership(authority);
    }

    function testSubmitClaimRevertsOwnableUnauthorizedAccount(
        address authorityOwner,
        uint256 epochLength,
        bool nonDeterministicDeployment,
        Claim memory claim
    ) external {
        IAuthority authority = _newAuthority(
            authorityOwner, epochLength, nonDeterministicDeployment
        );

        claim.appContract = _newActiveAppMock();

        claim.lastProcessedBlockNumber = _randomEpochFinalBlockNumber(epochLength);
        vm.roll(_randomUintGt(claim.lastProcessedBlockNumber));

        claim.proof = _randomLeafProof();

        address nonAuthorityOwner = _randomAddressDifferentFromZeroAnd(authorityOwner);

        vm.expectRevert(_encodeOwnableUnauthorizedAccount(nonAuthorityOwner));
        vm.prank(nonAuthorityOwner);
        authority.submitClaim(claim);
    }

    function testSubmitClaimRevertsNotEpochFinalBlock(
        address authorityOwner,
        uint256 epochLength,
        bool nonDeterministicDeployment,
        Claim memory claim
    ) external {
        uint256 lastProcessedBlockNumber = _randomNonEpochFinalBlock(epochLength);

        IAuthority authority =
            _newAuthority(authorityOwner, epochLength, nonDeterministicDeployment);

        claim.appContract = _newActiveAppMock();

        claim.lastProcessedBlockNumber = lastProcessedBlockNumber;
        vm.roll(_randomUintGt(claim.lastProcessedBlockNumber));

        claim.proof = _randomLeafProof();

        vm.expectRevert(_encodeNotEpochFinalBlock(lastProcessedBlockNumber, epochLength));
        vm.prank(authorityOwner);
        authority.submitClaim(claim);
    }

    function testSubmitClaimRevertNotPastBlock(
        address authorityOwner,
        uint256 epochLength,
        bool nonDeterministicDeployment,
        Claim memory claim
    ) external {
        IAuthority authority = _newAuthority(
            authorityOwner, epochLength, nonDeterministicDeployment
        );

        claim.appContract = _newActiveAppMock();

        // Adjust the lastProcessedBlockNumber but do not roll past it.
        claim.lastProcessedBlockNumber = _randomEpochFinalBlockNumber(epochLength);

        claim.proof = _randomLeafProof();

        vm.expectRevert(_encodeNotPastBlock(claim.lastProcessedBlockNumber));
        vm.prank(authorityOwner);
        authority.submitClaim(claim);
    }

    function testSubmitClaimRevertApplicationNotDeployed(
        address authorityOwner,
        uint256 epochLength,
        bool nonDeterministicDeployment,
        Claim memory claim
    ) external {
        IAuthority authority = _newAuthority(
            authorityOwner, epochLength, nonDeterministicDeployment
        );

        // We use a random account with no code as app contract
        claim.appContract = _randomAccountWithNoCode();

        claim.lastProcessedBlockNumber = _randomEpochFinalBlockNumber(epochLength);
        vm.roll(_randomUintGt(claim.lastProcessedBlockNumber));

        claim.proof = _randomLeafProof();

        vm.expectRevert(_encodeApplicationNotDeployed(claim.appContract));
        vm.prank(authorityOwner);
        authority.submitClaim(claim);
    }

    function testSubmitClaimRevertApplicationReverted(
        address authorityOwner,
        uint256 epochLength,
        bool nonDeterministicDeployment,
        Claim memory claim,
        bytes memory error
    ) external {
        IAuthority authority = _newAuthority(
            authorityOwner, epochLength, nonDeterministicDeployment
        );

        // We make isForeclosed() revert with an error
        claim.appContract = _newAppMockReverts(error);

        claim.lastProcessedBlockNumber = _randomEpochFinalBlockNumber(epochLength);
        vm.roll(_randomUintGt(claim.lastProcessedBlockNumber));

        claim.proof = _randomLeafProof();

        vm.expectRevert(_encodeApplicationReverted(claim.appContract, error));
        vm.prank(authorityOwner);
        authority.submitClaim(claim);
    }

    function testSubmitClaimRevertApplicationReturnIllSizedReturnData(
        address authorityOwner,
        uint256 epochLength,
        bool nonDeterministicDeployment,
        Claim memory claim,
        bytes memory data
    ) external {
        // We make isForeclosed() return ill-sized data
        vm.assume(data.length != 32);

        IAuthority authority =
            _newAuthority(authorityOwner, epochLength, nonDeterministicDeployment);

        claim.appContract = _newAppMockReturns(data);

        claim.lastProcessedBlockNumber = _randomEpochFinalBlockNumber(epochLength);
        vm.roll(_randomUintGt(claim.lastProcessedBlockNumber));

        claim.proof = _randomLeafProof();

        vm.expectRevert(_encodeIllformedApplicationReturnData(claim.appContract, data));
        vm.prank(authorityOwner);
        authority.submitClaim(claim);
    }

    function testSubmitClaimRevertApplicationReturnIllFormedReturnData(
        address authorityOwner,
        uint256 epochLength,
        bool nonDeterministicDeployment,
        Claim memory claim
    ) external {
        // We make isForeclosed() return an invalid boolean (neither 0 or 1)
        uint256 returnValue = vm.randomUint(2, type(uint256).max);

        IAuthority authority =
            _newAuthority(authorityOwner, epochLength, nonDeterministicDeployment);

        bytes memory data = abi.encode(returnValue);
        claim.appContract = _newAppMockReturns(data);

        claim.lastProcessedBlockNumber = _randomEpochFinalBlockNumber(epochLength);
        vm.roll(_randomUintGt(claim.lastProcessedBlockNumber));

        claim.proof = _randomLeafProof();

        vm.expectRevert(_encodeIllformedApplicationReturnData(claim.appContract, data));
        vm.prank(authorityOwner);
        authority.submitClaim(claim);
    }

    function testSubmitClaimRevertApplicationForeclosed(
        address authorityOwner,
        uint256 epochLength,
        bool nonDeterministicDeployment,
        Claim memory claim
    ) external {
        IAuthority authority = _newAuthority(
            authorityOwner, epochLength, nonDeterministicDeployment
        );

        // We make isForeclosed() return true
        claim.appContract = _newForeclosedAppMock();

        claim.lastProcessedBlockNumber = _randomEpochFinalBlockNumber(epochLength);
        vm.roll(_randomUintGt(claim.lastProcessedBlockNumber));

        claim.proof = _randomLeafProof();

        vm.expectRevert(_encodeApplicationForeclosed(claim.appContract));
        vm.prank(authorityOwner);
        authority.submitClaim(claim);
    }

    function testSubmitClaimRevertInvalidOutputsMerkleRootProofSize(
        address authorityOwner,
        uint256 epochLength,
        bool nonDeterministicDeployment,
        Claim memory claim
    ) external {
        IAuthority authority = _newAuthority(
            authorityOwner, epochLength, nonDeterministicDeployment
        );

        claim.appContract = _newActiveAppMock();

        claim.lastProcessedBlockNumber = _randomEpochFinalBlockNumber(epochLength);
        vm.roll(_randomUintGt(claim.lastProcessedBlockNumber));

        claim.proof = _randomProof(_randomInvalidLeafProofSize());

        vm.expectRevert(_encodeInvalidOutputsMerkleRootProofSize(claim.proof.length));
        vm.prank(authorityOwner);
        authority.submitClaim(claim);
    }

    function testSubmitClaim(
        address authorityOwner,
        uint256 epochLength,
        bool nonDeterministicDeployment,
        Claim memory claim
    ) external {
        IAuthority authority = _newAuthority(
            authorityOwner, epochLength, nonDeterministicDeployment
        );

        claim.appContract = _newActiveAppMock();

        address[] memory appContractSingleton = new address[](1);
        appContractSingleton[0] = claim.appContract;

        uint256[] memory blockNumbers = _randomEpochFinalBlockNumbers(epochLength);

        {
            (bool isEmpty, uint256 max) = blockNumbers.max();
            assertFalse(isEmpty, "unexpected empty array of epoch final block numbers");
            vm.roll(_randomUintGt(max));
        }

        bytes32 lastFinalizedMachineMerkleRoot;

        for (uint256 claimIndex; claimIndex < blockNumbers.length; ++claimIndex) {
            claim.lastProcessedBlockNumber = blockNumbers[claimIndex];
            claim.outputsMerkleRoot = _randomBytes32();
            claim.proof = _randomLeafProof();

            bytes32 machineMerkleRoot = claim.computeMachineMerkleRoot();

            uint256 totalNumOfSubmittedClaims =
                authority.getNumberOfSubmittedClaims(claim.appContract);
            uint256 totalNumOfAcceptedClaims =
                authority.getNumberOfAcceptedClaims(claim.appContract);

            vm.recordLogs();

            vm.prank(authority.owner());
            try authority.submitClaim(
                claim.appContract,
                claim.lastProcessedBlockNumber,
                claim.outputsMerkleRoot,
                claim.proof
            ) {}
            catch (bytes memory error) {
                (bytes4 errorSelector, bytes memory errorArgs) = error.consumeBytes4();
                if (errorSelector == IConsensus.NotFirstClaim.selector) {
                    (address arg1, uint256 arg2) =
                        abi.decode(errorArgs, (address, uint256));
                    assertEq(arg1, claim.appContract);
                    assertEq(arg2, claim.lastProcessedBlockNumber);
                    assertTrue(blockNumbers.containsBefore(arg2, claimIndex));
                } else {
                    revert("Unexpected error");
                }

                // Proceed to the next claim.
                continue;
            }

            {
                Vm.Log[] memory logs = vm.getRecordedLogs();

                uint256 numOfClaimSubmittedEvents;
                uint256 numOfClaimAcceptedEvents;

                for (uint256 i; i < logs.length; ++i) {
                    Vm.Log memory log = logs[i];
                    if (log.emitter == address(authority)) {
                        assertGe(log.topics.length, 1, "unexpected annonymous event");
                        bytes32 topic0 = log.topics[0];
                        if (topic0 == IConsensus.ClaimSubmitted.selector) {
                            (uint256 arg0, bytes32 arg1, bytes32 arg2) =
                                abi.decode(log.data, (uint256, bytes32, bytes32));
                            assertEq(log.topics[1], authority.owner().asTopic());
                            assertEq(log.topics[2], claim.appContract.asTopic());
                            assertEq(arg0, claim.lastProcessedBlockNumber);
                            assertEq(arg1, claim.outputsMerkleRoot);
                            assertEq(arg2, machineMerkleRoot);
                            ++numOfClaimSubmittedEvents;
                        } else if (topic0 == IConsensus.ClaimAccepted.selector) {
                            (uint256 arg0, bytes32 arg1, bytes32 arg2) =
                                abi.decode(log.data, (uint256, bytes32, bytes32));
                            assertEq(log.topics[1], claim.appContract.asTopic());
                            assertEq(arg0, claim.lastProcessedBlockNumber);
                            assertEq(arg1, claim.outputsMerkleRoot);
                            assertEq(arg2, machineMerkleRoot);
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
            }

            assertEq(
                authority.getNumberOfSubmittedClaims(claim.appContract),
                totalNumOfSubmittedClaims + 1,
                "Total number of submitted claims should be increased by number of events"
            );

            assertEq(
                authority.getNumberOfAcceptedClaims(claim.appContract),
                totalNumOfAcceptedClaims + 1,
                "Total number of accepted claims should be increased by number of events"
            );

            address notAppContract = vm.randomAddressNotIn(appContractSingleton);

            assertEq(
                authority.getNumberOfSubmittedClaims(notAppContract),
                0,
                "Total number of submitted claims should be zero for other apps"
            );

            assertEq(
                authority.getNumberOfAcceptedClaims(notAppContract),
                0,
                "Total number of submitted claims should be zero for other apps"
            );

            {
                (bool isEmpty, uint256 max) = blockNumbers.maxBefore(claimIndex);

                // If the claim was successful submitted, then its last processed
                // block number cannot be equal to any past successful claim.
                if (isEmpty || claim.lastProcessedBlockNumber > max) {
                    lastFinalizedMachineMerkleRoot = machineMerkleRoot;
                }
            }

            assertTrue(
                authority.isOutputsMerkleRootValid(
                    claim.appContract, claim.outputsMerkleRoot
                ),
                "Once a claim is accepted, the outputs Merkle root is valid"
            );

            assertFalse(
                authority.isOutputsMerkleRootValid(notAppContract, _randomBytes32()),
                "Valid output Merkle roots for other apps should remain the same"
            );

            assertEq(
                authority.getLastFinalizedMachineMerkleRoot(claim.appContract),
                lastFinalizedMachineMerkleRoot,
                "Check last finalized machine Merkle root"
            );

            assertEq(
                authority.getLastFinalizedMachineMerkleRoot(notAppContract),
                bytes32(0),
                "Last finalized machine Merkle root for other apps should remain the same"
            );
        }
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

        _testVersion(authority);

        assertEq(authority.owner(), authorityOwner, "owner() == authorityOwner");
        assertNotEq(authorityOwner, address(0), "owner() != address(0)");

        assertEq(
            authority.getEpochLength(), epochLength, "getEpochLength() == epochLength"
        );
        assertGt(epochLength, 0, "getEpochLength() > 0");

        // We check that initially all outputs Merkle roots are invalid.
        assertFalse(
            authority.isOutputsMerkleRootValid(vm.randomAddress(), _randomBytes32()),
            "initially, isOutputsMerkleRootValid(...) == false"
        );

        // We check that initially no machine Merkle root has been finalized.
        assertEq(
            authority.getLastFinalizedMachineMerkleRoot(vm.randomAddress()),
            bytes32(0),
            "initially, getLastFinalizedMachineMerkleRoot(...) == bytes32(0)"
        );

        // Also, initially, no `ClaimSubmitted` or `ClaimAccepted` were emitted.
        assertEq(
            authority.getNumberOfSubmittedClaims(vm.randomAddress()),
            0,
            "initially, getNumberOfSubmittedClaims(...) == 0"
        );
        assertEq(
            authority.getNumberOfAcceptedClaims(vm.randomAddress()),
            0,
            "initially, getNumberOfAcceptedClaims(...) == 0"
        );

        // Test ERC-165 interface
        _testSupportsInterface(authority, interfaceId);
    }

    function _testNewAuthorityFailure(uint256 epochLength, string memory message)
        internal
        pure
    {
        bytes32 messageHash = keccak256(bytes(message));
        if (messageHash == keccak256("epoch length must not be zero")) {
            assertEq(epochLength, 0, "expected epoch length to be zero");
        } else {
            revert("Unexpected error message");
        }
    }

    function _testNewAuthorityFailure(address authorityOwner, bytes memory error)
        internal
        pure
    {
        (bytes4 errorSelector, bytes memory errorArgs) = error.consumeBytes4();
        if (errorSelector == Ownable.OwnableInvalidOwner.selector) {
            address owner = abi.decode(errorArgs, (address));
            assertEq(owner, authorityOwner, "OwnableInvalidOwner.owner != owner");
            assertEq(owner, address(0), "OwnableInvalidOwner.owner != address(0)");
        } else {
            revert("Unexpected error");
        }
    }

    function _newAuthority(
        address authorityOwner,
        uint256 epochLength,
        bool nonDeterministicDeployment
    ) internal returns (IAuthority) {
        if (nonDeterministicDeployment) {
            vm.assumeNoRevert();
            return _factory.newAuthority(authorityOwner, epochLength);
        } else {
            bytes32 salt = _randomBytes32();
            vm.assumeNoRevert();
            return _factory.newAuthority(authorityOwner, epochLength, salt);
        }
    }
}
