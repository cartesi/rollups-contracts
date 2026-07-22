// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {Ownable} from "@openzeppelin-contracts-5.2.0/access/Ownable.sol";

import {Vm} from "forge-std-1.9.6/src/Vm.sol";

import {IConsensus} from "src/consensus/IConsensus.sol";
import {IConsensusFactoryErrors} from "src/consensus/IConsensusFactoryErrors.sol";
import {IOutputsMerkleRootValidator} from "src/consensus/IOutputsMerkleRootValidator.sol";
import {IAuthority} from "src/consensus/authority/IAuthority.sol";
import {IAuthorityFactory} from "src/consensus/authority/IAuthorityFactory.sol";

import {ApplicationForeclosureMock} from "../../util/ApplicationForeclosureMock.sol";
import {Claim} from "../../util/Claim.sol";
import {ConsensusTestUtils} from "../../util/ConsensusTestUtils.sol";
import {Erc165Test} from "../../util/Erc165Test.sol";
import {LibAddressArray} from "../../util/LibAddressArray.sol";
import {LibBytes} from "../../util/LibBytes.sol";
import {LibConsensus} from "../../util/LibConsensus.sol";
import {LibTopic} from "../../util/LibTopic.sol";
import {LibUint256Array} from "../../util/LibUint256Array.sol";
import {OwnableTest} from "../../util/OwnableTest.sol";
import {RollupsTest} from "../../util/RollupsTest.sol";
import {VersionGetterTestUtils} from "../../util/VersionGetterTestUtils.sol";

struct DeploymentArgs {
    bool deterministic;
    address authorityOwner;
    uint256 epochLength;
    uint256 claimStagingPeriod;
    bytes32 salt;
}

library LibAuthorityFactory {
    function newAuthority(
        IAuthorityFactory factory,
        DeploymentArgs calldata deploymentArgs
    ) external returns (IAuthority) {
        return deploymentArgs.deterministic
            ? factory.newAuthority(
                deploymentArgs.authorityOwner,
                deploymentArgs.epochLength,
                deploymentArgs.claimStagingPeriod,
                deploymentArgs.salt
            )
            : factory.newAuthority(
                deploymentArgs.authorityOwner,
                deploymentArgs.epochLength,
                deploymentArgs.claimStagingPeriod
            );
    }

    function calculateAuthorityAddress(
        IAuthorityFactory factory,
        DeploymentArgs calldata deploymentArgs
    ) external view returns (address) {
        return factory.calculateAuthorityAddress(
            deploymentArgs.authorityOwner,
            deploymentArgs.epochLength,
            deploymentArgs.claimStagingPeriod,
            deploymentArgs.salt
        );
    }
}

contract AuthorityFactoryTest is
    RollupsTest,
    Erc165Test,
    OwnableTest,
    ConsensusTestUtils,
    VersionGetterTestUtils
{
    using LibAuthorityFactory for IAuthorityFactory;
    using LibUint256Array for uint256[];
    using LibConsensus for IAuthority;
    using LibAddressArray for Vm;
    using LibTopic for address;
    using LibBytes for bytes;

    IAuthorityFactory _factory;

    function setUp() public {
        _factory = _contracts.core.authorityFactory;
        _supportedInterfaces.push(type(IOutputsMerkleRootValidator).interfaceId);
        _supportedInterfaces.push(type(IConsensus).interfaceId);
        _supportedInterfaces.push(type(IAuthority).interfaceId);
    }

    function testVersion() external view {
        _testVersion(_factory);
    }

    function testNewAuthority(DeploymentArgs calldata deploymentArgs) external {
        address authorityAddress = _factory.calculateAuthorityAddress(deploymentArgs);

        vm.recordLogs();

        try _factory.newAuthority(deploymentArgs) returns (IAuthority authority) {
            Vm.Log[] memory logs = vm.getRecordedLogs();

            if (deploymentArgs.deterministic) {
                assertEq(
                    authorityAddress,
                    address(authority),
                    "calculateAuthorityAddress(...) != newAuthority(...)"
                );
            }

            uint256 numOfAuthorityCreated;
            uint256 numOfOwnershipTransferred;

            for (uint256 i; i < logs.length; ++i) {
                Vm.Log memory log = logs[i];
                if (log.emitter == address(_factory)) {
                    bytes32 topic0 = log.topics[0];
                    if (topic0 == IAuthorityFactory.AuthorityCreated.selector) {
                        ++numOfAuthorityCreated;
                        address arg1 = abi.decode(log.data, (address));
                        assertEq(arg1, address(authority));
                    } else {
                        revert UnexpectedLog(log);
                    }
                } else if (log.emitter == address(authority)) {
                    bytes32 topic0 = log.topics[0];
                    if (topic0 == Ownable.OwnershipTransferred.selector) {
                        ++numOfOwnershipTransferred;
                        assertEq(log.topics[1], address(0).asTopic());
                        assertEq(log.topics[2], deploymentArgs.authorityOwner.asTopic());
                    } else {
                        revert UnexpectedLog(log);
                    }
                } else {
                    revert UnexpectedLog(log);
                }
            }

            assertEq(numOfAuthorityCreated, 1);
            assertEq(numOfOwnershipTransferred, 1);

            // Test getters
            assertEq(authority.owner(), deploymentArgs.authorityOwner);
            assertNotEq(deploymentArgs.authorityOwner, address(0));
            assertEq(authority.getEpochLength(), deploymentArgs.epochLength);
            assertGt(deploymentArgs.epochLength, 0);
            assertEq(authority.getClaimStagingPeriod(), deploymentArgs.claimStagingPeriod);

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

            // We check that initially no input was finalized.
            assertFalse(
                authority.wasInputFinalized(
                    vm.randomAddress(), // appContract
                    vm.randomUint(), // inputIndex
                    vm.randomUint() // blockNumber
                ),
                "initially, wasInputFinalized(...) == false"
            );

            Claim memory randomClaim;
            randomClaim.appContract = vm.randomAddress();
            randomClaim.lastProcessedBlockNumber = vm.randomUint();
            randomClaim.machineMerkleRoot = _randomBytes32();
            IConsensus.Claim memory stagedClaimInfo = authority.getClaim(randomClaim);

            // We check that initially no claim is staged.
            assertEq(
                uint256(stagedClaimInfo.status),
                uint256(IConsensus.ClaimStatus.UNSTAGED),
                "initially, getClaim(...).status == ClaimStatus.UNSTAGED"
            );

            // Also, initially, no claim-related events were emitted.
            assertEq(authority.getNumberOfSubmittedClaims(vm.randomAddress()), 0);
            assertEq(authority.getNumberOfStagedClaims(vm.randomAddress()), 0);
            assertEq(authority.getNumberOfAcceptedClaims(vm.randomAddress()), 0);

            // Test ERC-165 interface
            _testSupportsInterface(authority);

            // Test version
            _testVersion(authority);

            if (deploymentArgs.deterministic) {
                assertEq(
                    _factory.calculateAuthorityAddress(deploymentArgs),
                    authorityAddress,
                    "calculateAuthorityAddress(...) is not a pure function"
                );

                // Cannot deploy an application with the same salt twice
                try _factory.newAuthority(deploymentArgs) {
                    revert("second deterministic deployment did not revert");
                } catch (bytes memory errorData) {
                    assertEq(
                        errorData,
                        new bytes(0),
                        "second deterministic deployment did not revert with empty error data"
                    );
                }
            }
        } catch (bytes memory errorData) {
            (bytes4 selector, bytes memory errorArgs) = errorData.consumeBytes4();
            if (selector == Ownable.OwnableInvalidOwner.selector) {
                address owner = abi.decode(errorArgs, (address));
                assertEq(owner, deploymentArgs.authorityOwner);
                assertEq(owner, address(0));
            } else if (selector == IConsensusFactoryErrors.ZeroEpochLength.selector) {
                assertEq(errorArgs.length, 0);
                assertEq(deploymentArgs.epochLength, 0);
            } else {
                revert UnexpectedError(errorData);
            }
        }
    }

    function testRenounceOwnership(DeploymentArgs calldata deploymentArgs) external {
        _testRenounceOwnership(_newAuthority(deploymentArgs));
    }

    function testUnauthorizedAccount(DeploymentArgs calldata deploymentArgs) external {
        _testUnauthorizedAccount(_newAuthority(deploymentArgs));
    }

    function testInvalidOwner(DeploymentArgs calldata deploymentArgs) external {
        _testInvalidOwner(_newAuthority(deploymentArgs));
    }

    function testTransferOwnership(DeploymentArgs calldata deploymentArgs) external {
        _testTransferOwnership(_newAuthority(deploymentArgs));
    }

    function testSubmitClaimRevertsOwnableUnauthorizedAccount(DeploymentArgs calldata deploymentArgs)
        external
    {
        (IAuthority authority, Claim memory claim) = _newAuthorityAndClaim(deploymentArgs);

        _rollPast(claim.lastProcessedBlockNumber);

        address nonAuthorityOwner =
            _randomAddressDifferentFromZeroAnd(deploymentArgs.authorityOwner);

        vm.expectRevert(_encodeOwnableUnauthorizedAccount(nonAuthorityOwner));
        vm.prank(nonAuthorityOwner);
        authority.submitClaim(claim);
    }

    function testSubmitClaimRevertsNotEpochFinalBlock(DeploymentArgs calldata deploymentArgs)
        external
    {
        (IAuthority authority, Claim memory claim) = _newAuthorityAndClaim(deploymentArgs);
        claim.lastProcessedBlockNumber =
            _randomNonEpochFinalBlock(deploymentArgs.epochLength);

        _rollPast(claim.lastProcessedBlockNumber);

        vm.expectRevert(
            _encodeNotEpochFinalBlock(
                claim.lastProcessedBlockNumber, deploymentArgs.epochLength
            )
        );
        vm.prank(deploymentArgs.authorityOwner);
        authority.submitClaim(claim);
    }

    function testSubmitClaimRevertNotPastBlock(DeploymentArgs calldata deploymentArgs)
        external
    {
        (IAuthority authority, Claim memory claim) = _newAuthorityAndClaim(deploymentArgs);

        vm.expectRevert(_encodeNotPastBlock(claim.lastProcessedBlockNumber));
        vm.prank(deploymentArgs.authorityOwner);
        authority.submitClaim(claim);
    }

    function testSubmitClaimRevertApplicationNotDeployed(DeploymentArgs calldata deploymentArgs)
        external
    {
        (IAuthority authority, Claim memory claim) = _newAuthorityAndClaim(deploymentArgs);
        claim.appContract = _randomAccountWithNoCode();

        _rollPast(claim.lastProcessedBlockNumber);

        vm.expectRevert(_encodeApplicationNotDeployed(claim.appContract));
        vm.prank(deploymentArgs.authorityOwner);
        authority.submitClaim(claim);
    }

    function testSubmitClaimRevertApplicationReverted(
        DeploymentArgs calldata deploymentArgs,
        bytes memory errorData
    ) external {
        (IAuthority authority, Claim memory claim) = _newAuthorityAndClaim(deploymentArgs);
        claim.appContract = _newAppMockIsForeclosedReverts(errorData);

        _rollPast(claim.lastProcessedBlockNumber);

        vm.expectRevert(_encodeApplicationReverted(claim.appContract, errorData));
        vm.prank(deploymentArgs.authorityOwner);
        authority.submitClaim(claim);
    }

    function testSubmitClaimRevertApplicationReturnIllSizedReturnData(
        DeploymentArgs calldata deploymentArgs,
        bytes memory data
    ) external {
        vm.assume(data.length != 32);

        (IAuthority authority, Claim memory claim) = _newAuthorityAndClaim(deploymentArgs);
        claim.appContract = _newAppMockIsForeclosedReturns(data);

        _rollPast(claim.lastProcessedBlockNumber);

        vm.expectRevert(_encodeIllformedApplicationReturnData(claim.appContract, data));
        vm.prank(deploymentArgs.authorityOwner);
        authority.submitClaim(claim);
    }

    function testSubmitClaimRevertApplicationReturnIllFormedReturnData(DeploymentArgs calldata deploymentArgs)
        external
    {
        bytes memory data = abi.encode(vm.randomUint(2, type(uint256).max));

        (IAuthority authority, Claim memory claim) = _newAuthorityAndClaim(deploymentArgs);
        claim.appContract = _newAppMockIsForeclosedReturns(data);

        _rollPast(claim.lastProcessedBlockNumber);

        vm.expectRevert(_encodeIllformedApplicationReturnData(claim.appContract, data));
        vm.prank(deploymentArgs.authorityOwner);
        authority.submitClaim(claim);
    }

    function testSubmitClaimRevertApplicationForeclosed(DeploymentArgs calldata deploymentArgs)
        external
    {
        (IAuthority authority, Claim memory claim) = _newAuthorityAndClaim(deploymentArgs);
        claim.appContract = _newForeclosedAppMock();

        _rollPast(claim.lastProcessedBlockNumber);

        vm.expectRevert(_encodeApplicationForeclosed(claim.appContract));
        vm.prank(deploymentArgs.authorityOwner);
        authority.submitClaim(claim);
    }

    function testSubmitClaimRevertInvalidSiblingsArrayLength(DeploymentArgs calldata deploymentArgs)
        external
    {
        (IAuthority authority, Claim memory claim) = _newAuthorityAndClaim(deploymentArgs);
        _invalidateSiblingsArray(_pickRandomLeafProofFrom(claim.proof));

        _rollPast(claim.lastProcessedBlockNumber);

        vm.expectRevert(_encodeInvalidSiblingsArrayLength());
        vm.prank(deploymentArgs.authorityOwner);
        authority.submitClaim(claim);
    }

    function testSubmitClaimRevertInvalidMachineMerkleProof(DeploymentArgs calldata deploymentArgs)
        external
    {
        (IAuthority authority, Claim memory claim) = _newAuthorityAndClaim(deploymentArgs);
        _alterDataBlock(_pickRandomLeafProofFrom(claim.proof));

        _rollPast(claim.lastProcessedBlockNumber);

        vm.expectRevert(_encodeInvalidMachineMerkleProof());
        vm.prank(deploymentArgs.authorityOwner);
        authority.submitClaim(claim);
    }

    function testSubmitClaimRevertInvalidPostEpochMachineIflagsYRegister(DeploymentArgs calldata deploymentArgs)
        external
    {
        IAuthority authority = _newAuthority(deploymentArgs);
        Claim memory claim = _newClaim(deploymentArgs.epochLength, _initBadIflagsY);

        _rollPast(claim.lastProcessedBlockNumber);

        vm.expectRevert(_encodeInvalidPostEpochMachineIflagsYRegister());
        vm.prank(deploymentArgs.authorityOwner);
        authority.submitClaim(claim);
    }

    function testSubmitClaimRevertInvalidPostEpochMachineHtifTohostRegister(DeploymentArgs calldata deploymentArgs)
        external
    {
        IAuthority authority = _newAuthority(deploymentArgs);
        Claim memory claim = _newClaim(deploymentArgs.epochLength, _initBadHtifTohost);

        _rollPast(claim.lastProcessedBlockNumber);

        vm.expectRevert(_encodeInvalidPostEpochMachineHtifTohostRegister());
        vm.prank(deploymentArgs.authorityOwner);
        authority.submitClaim(claim);
    }

    function testSubmitAndAcceptClaim(DeploymentArgs calldata deploymentArgs) external {
        IAuthority authority = _newAuthority(deploymentArgs);
        address appContract = address(new ApplicationForeclosureMock());
        address authorityOwner = deploymentArgs.authorityOwner;

        address[] memory appContractSingleton = new address[](1);
        appContractSingleton[0] = appContract;

        uint256[] memory blockNumbers =
            _randomEpochFinalBlockNumbers(deploymentArgs.epochLength);

        {
            (bool isEmpty, uint256 maxBlockNumber) = blockNumbers.max();
            assertFalse(isEmpty, "unexpected empty array of epoch final block numbers");
            _rollPast(maxBlockNumber);
        }

        bytes32 lastFinalizedMachineMerkleRoot;
        uint256 firstUnprocessedBlockNumber;

        for (uint256 claimIndex; claimIndex < blockNumbers.length; ++claimIndex) {
            uint256 blockNumber = blockNumbers[claimIndex];
            bool notFirstClaim = blockNumbers.containsBefore(blockNumber, claimIndex);

            Claim memory claim = _randomClaim(appContract, blockNumber);

            bytes32 machineMerkleRoot = claim.machineMerkleRoot;
            bytes32 outputsMerkleRoot = claim.proof.txBufferProof.dataBlock;

            uint256 totalNumOfSubmittedClaims =
                authority.getNumberOfSubmittedClaims(appContract);
            uint256 totalNumOfStagedClaims =
                authority.getNumberOfStagedClaims(appContract);
            uint256 totalNumOfAcceptedClaims =
                authority.getNumberOfAcceptedClaims(appContract);

            vm.expectRevert(
                notFirstClaim
                    ? _encodeNotFirstClaim(claim)
                    : _encodeApplicationForeclosed(appContract)
            );
            this.simulateForeclosureAndClaimSubmission(authority, authorityOwner, claim);

            if (notFirstClaim) {
                vm.expectRevert(_encodeNotFirstClaim(claim));
            } else {
                vm.recordLogs();
            }

            vm.prank(authorityOwner);
            authority.submitClaim(claim);

            if (notFirstClaim) {
                continue; // Proceed to next claim.
            }

            Vm.Log[] memory logs = vm.getRecordedLogs();

            uint256 numOfClaimSubmittedEvents;
            uint256 numOfClaimStagedEvents;

            for (uint256 i; i < logs.length; ++i) {
                Vm.Log memory log = logs[i];
                if (log.emitter == address(authority)) {
                    require(log.topics.length >= 1, UnexpectedLog(log));
                    bytes32 topic0 = log.topics[0];
                    if (topic0 == IConsensus.ClaimSubmitted.selector) {
                        (uint256 arg0, bytes32 arg1, bytes32 arg2) =
                            abi.decode(log.data, (uint256, bytes32, bytes32));
                        assertEq(log.topics.length, 3);
                        assertEq(log.topics[1], authorityOwner.asTopic());
                        assertEq(log.topics[2], appContract.asTopic());
                        assertEq(arg0, blockNumber);
                        assertEq(arg1, outputsMerkleRoot);
                        assertEq(arg2, machineMerkleRoot);
                        ++numOfClaimSubmittedEvents;
                    } else if (topic0 == IConsensus.ClaimStaged.selector) {
                        (uint256 arg0, bytes32 arg1, bytes32 arg2) =
                            abi.decode(log.data, (uint256, bytes32, bytes32));
                        assertEq(log.topics[1], appContract.asTopic());
                        assertEq(arg0, blockNumber);
                        assertEq(arg1, outputsMerkleRoot);
                        assertEq(arg2, machineMerkleRoot);
                        ++numOfClaimStagedEvents;
                    } else {
                        revert UnexpectedLog(log);
                    }
                } else {
                    revert UnexpectedLog(log);
                }
            }

            assertEq(numOfClaimSubmittedEvents, 1, "expected 1 ClaimSubmitted event");
            assertEq(numOfClaimStagedEvents, 1, "expected 1 ClaimStaged event");

            assertEq(
                authority.getNumberOfSubmittedClaims(appContract),
                totalNumOfSubmittedClaims + 1,
                "Total number of submitted claims should be increased by number of events"
            );

            assertEq(
                authority.getNumberOfStagedClaims(appContract),
                totalNumOfStagedClaims + 1,
                "Total number of staged claims should be increased by number of events"
            );

            assertEq(
                authority.getNumberOfAcceptedClaims(appContract),
                totalNumOfAcceptedClaims,
                "Total number of accepted claims should be the same after a submission"
            );

            IConsensus.Claim memory stagedClaimInfo = authority.getClaim(claim);

            assertEq(
                uint256(stagedClaimInfo.status),
                uint256(IConsensus.ClaimStatus.STAGED),
                "After staging, getClaim(...).status == ClaimStatus.STAGED"
            );

            assertEq(
                stagedClaimInfo.stagingBlockNumber,
                vm.getBlockNumber(),
                "After staging, getClaim(...).stagingBlockNumber == block.number"
            );

            assertEq(
                stagedClaimInfo.stagedOutputsMerkleRoot,
                outputsMerkleRoot,
                "After staging, getClaim(...).stagedOutputsMerkleRoot == outputsMerkleRoot"
            );

            address notAppContract = vm.randomAddressNotIn(appContractSingleton);

            assertEq(
                authority.getNumberOfSubmittedClaims(notAppContract),
                0,
                "Total number of submitted claims should be zero for other apps"
            );

            assertEq(
                authority.getNumberOfStagedClaims(notAppContract),
                0,
                "Total number of staged claims should be zero for other apps"
            );

            assertEq(
                authority.getNumberOfAcceptedClaims(notAppContract),
                0,
                "Total number of accepted claims should be zero for other apps"
            );

            {
                (bool isEmpty, uint256 max) = blockNumbers.maxBefore(claimIndex);

                // If the claim was successfully accepted, then its last processed
                // block number cannot be equal to any past successful claim.
                if (isEmpty || blockNumber > max) {
                    lastFinalizedMachineMerkleRoot = machineMerkleRoot;
                    firstUnprocessedBlockNumber = blockNumber + 1;
                }
            }

            if (deploymentArgs.claimStagingPeriod >= 1) {
                vm.roll(
                    vm.randomUint(
                        vm.getBlockNumber(),
                        _boundedSum(
                            stagedClaimInfo.stagingBlockNumber,
                            deploymentArgs.claimStagingPeriod - 1
                        )
                    )
                );

                uint256 numberOfBlocksAfterStaging =
                    vm.getBlockNumber() - stagedClaimInfo.stagingBlockNumber;

                vm.expectRevert(
                    _encodeClaimStagingPeriodNotOverYet(
                        appContract,
                        blockNumber,
                        machineMerkleRoot,
                        numberOfBlocksAfterStaging,
                        deploymentArgs.claimStagingPeriod
                    )
                );
                vm.prank(vm.randomAddress());
                authority.acceptClaim(claim);
            }

            if (
                deploymentArgs.claimStagingPeriod
                    > type(uint256).max - stagedClaimInfo.stagingBlockNumber
            ) {
                continue; // Cannot go past the claim staging period
            }

            vm.roll(
                vm.randomUint(
                    stagedClaimInfo.stagingBlockNumber
                        + deploymentArgs.claimStagingPeriod,
                    type(uint256).max
                )
            );

            vm.expectRevert(_encodeApplicationForeclosed(appContract));
            this.simulateForeclosureAndClaimAcceptance(authority, claim);

            vm.recordLogs();

            vm.prank(vm.randomAddress());
            authority.acceptClaim(appContract, blockNumber, machineMerkleRoot);

            logs = vm.getRecordedLogs();

            uint256 numOfClaimAcceptedEvents;

            for (uint256 i; i < logs.length; ++i) {
                Vm.Log memory log = logs[i];
                if (log.emitter == address(authority)) {
                    require(log.topics.length >= 1, UnexpectedLog(log));
                    bytes32 topic0 = log.topics[0];
                    if (topic0 == IConsensus.ClaimAccepted.selector) {
                        (uint256 arg0, bytes32 arg1, bytes32 arg2) =
                            abi.decode(log.data, (uint256, bytes32, bytes32));
                        assertEq(log.topics[1], appContract.asTopic());
                        assertEq(arg0, blockNumber);
                        assertEq(arg1, outputsMerkleRoot);
                        assertEq(arg2, machineMerkleRoot);
                        ++numOfClaimAcceptedEvents;
                    } else {
                        revert UnexpectedLog(log);
                    }
                } else {
                    revert UnexpectedLog(log);
                }
            }

            assertEq(numOfClaimAcceptedEvents, 1, "expected 1 ClaimAccepted event");

            assertEq(
                authority.getNumberOfSubmittedClaims(appContract),
                totalNumOfSubmittedClaims + 1,
                "Total number of submitted claims should be increased by number of events"
            );

            assertEq(
                authority.getNumberOfStagedClaims(appContract),
                totalNumOfStagedClaims + 1,
                "Total number of staged claims should be increased by number of events"
            );

            assertEq(
                authority.getNumberOfAcceptedClaims(appContract),
                totalNumOfAcceptedClaims + 1,
                "Total number of accepted claims should be increased by number of events"
            );

            IConsensus.Claim memory acceptedClaimInfo = authority.getClaim(claim);

            assertEq(
                uint256(acceptedClaimInfo.status),
                uint256(IConsensus.ClaimStatus.ACCEPTED),
                "After acceptance, getClaim(...).status == ClaimStatus.ACCEPTED"
            );

            assertEq(
                acceptedClaimInfo.stagingBlockNumber,
                stagedClaimInfo.stagingBlockNumber,
                "After acceptance, getClaim(...).stagingBlockNumber stays the same"
            );

            assertEq(
                acceptedClaimInfo.stagedOutputsMerkleRoot,
                stagedClaimInfo.stagedOutputsMerkleRoot,
                "After acceptance, getClaim(...).stagedOutputsMerkleRoot stays the same"
            );

            assertTrue(
                authority.isOutputsMerkleRootValid(appContract, outputsMerkleRoot),
                "Once a claim is accepted, the outputs Merkle root is valid"
            );

            assertFalse(
                authority.isOutputsMerkleRootValid(notAppContract, _randomBytes32()),
                "Valid output Merkle roots for other apps should remain the same"
            );

            assertEq(
                authority.getLastFinalizedMachineMerkleRoot(appContract),
                lastFinalizedMachineMerkleRoot,
                "Check last finalized machine Merkle root"
            );

            if (firstUnprocessedBlockNumber >= 1) {
                assertTrue(
                    authority.wasInputFinalized(
                        appContract,
                        vm.randomUint(), // inputIndex
                        vm.randomUint(0, firstUnprocessedBlockNumber - 1)
                    ),
                    "Check all inputs added before the first unprocessed block were finalized"
                );
            }

            assertFalse(
                authority.wasInputFinalized(
                    appContract,
                    vm.randomUint(), // inputIndex
                    vm.randomUint(firstUnprocessedBlockNumber, type(uint256).max)
                ),
                "Check all inputs added on the first unprocessed block or after were not finalized"
            );

            assertFalse(
                authority.wasInputFinalized(
                    notAppContract,
                    vm.randomUint(), // inputIndex
                    vm.randomUint() // blockNumber
                ),
                "Check all inputs from other apps were not finalized"
            );

            assertEq(
                authority.getLastFinalizedMachineMerkleRoot(notAppContract),
                bytes32(0),
                "Last finalized machine Merkle root for other apps should remain the same"
            );

            vm.expectRevert(_encodeClaimNotStagedButAccepted(claim));
            vm.prank(vm.randomAddress());
            authority.acceptClaim(claim);
        }
    }

    function testAcceptClaimRevertApplicationNotDeployed(DeploymentArgs calldata deploymentArgs)
        external
    {
        (IAuthority authority, Claim memory claim) = _newAuthorityAndClaim(deploymentArgs);
        claim.appContract = _randomAccountWithNoCode();

        _rollPast(claim.lastProcessedBlockNumber);

        vm.expectRevert(_encodeApplicationNotDeployed(claim.appContract));
        vm.prank(vm.randomAddress());
        authority.acceptClaim(claim);
    }

    function testAcceptClaimRevertApplicationReverted(
        DeploymentArgs calldata deploymentArgs,
        bytes memory errorData
    ) external {
        (IAuthority authority, Claim memory claim) = _newAuthorityAndClaim(deploymentArgs);
        claim.appContract = _newAppMockIsForeclosedReverts(errorData);

        _rollPast(claim.lastProcessedBlockNumber);

        vm.expectRevert(_encodeApplicationReverted(claim.appContract, errorData));
        vm.prank(vm.randomAddress());
        authority.acceptClaim(claim);
    }

    function testAcceptClaimRevertApplicationReturnIllSizedReturnData(
        DeploymentArgs calldata deploymentArgs,
        bytes memory data
    ) external {
        vm.assume(data.length != 32);

        (IAuthority authority, Claim memory claim) = _newAuthorityAndClaim(deploymentArgs);
        claim.appContract = _newAppMockIsForeclosedReturns(data);

        _rollPast(claim.lastProcessedBlockNumber);

        vm.expectRevert(_encodeIllformedApplicationReturnData(claim.appContract, data));
        vm.prank(vm.randomAddress());
        authority.acceptClaim(claim);
    }

    function testAcceptClaimRevertApplicationReturnIllFormedReturnData(DeploymentArgs calldata deploymentArgs)
        external
    {
        bytes memory data = abi.encode(vm.randomUint(2, type(uint256).max));

        (IAuthority authority, Claim memory claim) = _newAuthorityAndClaim(deploymentArgs);
        claim.appContract = _newAppMockIsForeclosedReturns(data);

        _rollPast(claim.lastProcessedBlockNumber);

        vm.expectRevert(_encodeIllformedApplicationReturnData(claim.appContract, data));
        vm.prank(vm.randomAddress());
        authority.acceptClaim(claim);
    }

    function testAcceptClaimRevertApplicationForeclosed(DeploymentArgs calldata deploymentArgs)
        external
    {
        (IAuthority authority, Claim memory claim) = _newAuthorityAndClaim(deploymentArgs);
        claim.appContract = _newForeclosedAppMock();

        _rollPast(claim.lastProcessedBlockNumber);

        vm.expectRevert(_encodeApplicationForeclosed(claim.appContract));
        vm.prank(vm.randomAddress());
        authority.acceptClaim(claim);
    }

    function testAcceptClaimRevertsNotEpochFinalBlock(DeploymentArgs calldata deploymentArgs)
        external
    {
        (IAuthority authority, Claim memory claim) = _newAuthorityAndClaim(deploymentArgs);
        claim.lastProcessedBlockNumber =
            _randomNonEpochFinalBlock(deploymentArgs.epochLength);

        _rollPast(claim.lastProcessedBlockNumber);

        vm.expectRevert(
            _encodeNotEpochFinalBlock(
                claim.lastProcessedBlockNumber, deploymentArgs.epochLength
            )
        );
        vm.prank(vm.randomAddress());
        authority.acceptClaim(claim);
    }

    function testAcceptClaimRevertsNotPastBlock(DeploymentArgs calldata deploymentArgs)
        external
    {
        (IAuthority authority, Claim memory claim) = _newAuthorityAndClaim(deploymentArgs);

        vm.expectRevert(_encodeNotPastBlock(claim.lastProcessedBlockNumber));
        vm.prank(vm.randomAddress());
        authority.acceptClaim(claim);
    }

    function testAcceptClaimRevertsUnstagedClaim(DeploymentArgs calldata deploymentArgs)
        external
    {
        (IAuthority authority, Claim memory claim) = _newAuthorityAndClaim(deploymentArgs);

        _rollPast(claim.lastProcessedBlockNumber);

        vm.expectRevert(_encodeClaimNotStagedButUnstaged(claim));
        vm.prank(vm.randomAddress());
        authority.acceptClaim(claim);
    }

    function _newAuthority(DeploymentArgs calldata deploymentArgs)
        internal
        returns (IAuthority)
    {
        vm.assumeNoRevert();
        return _factory.newAuthority(deploymentArgs);
    }

    function _newAuthorityAndClaim(DeploymentArgs calldata deploymentArgs)
        internal
        returns (IAuthority authority, Claim memory claim)
    {
        authority = _newAuthority(deploymentArgs);
        claim = _randomClaim(deploymentArgs.epochLength);
    }
}
