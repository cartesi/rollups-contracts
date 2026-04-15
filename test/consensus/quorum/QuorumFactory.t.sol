// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {IConsensus} from "src/consensus/IConsensus.sol";
import {IConsensusFactoryErrors} from "src/consensus/IConsensusFactoryErrors.sol";
import {IQuorum} from "src/consensus/quorum/IQuorum.sol";
import {IQuorumFactory} from "src/consensus/quorum/IQuorumFactory.sol";
import {IQuorumFactoryErrors} from "src/consensus/quorum/IQuorumFactoryErrors.sol";
import {QuorumFactory} from "src/consensus/quorum/QuorumFactory.sol";
import {IApplicationChecker} from "src/dapp/IApplicationChecker.sol";

import {ApplicationForeclosureMock} from "../../util/ApplicationForeclosureMock.sol";
import {Claim} from "../../util/Claim.sol";
import {ConsensusTestUtils} from "../../util/ConsensusTestUtils.sol";
import {ERC165Test} from "../../util/ERC165Test.sol";
import {LibAddressArray} from "../../util/LibAddressArray.sol";
import {LibBytes} from "../../util/LibBytes.sol";
import {LibClaim} from "../../util/LibClaim.sol";
import {LibConsensus} from "../../util/LibConsensus.sol";
import {LibTopic} from "../../util/LibTopic.sol";
import {LibUint256Array} from "../../util/LibUint256Array.sol";
import {VersionGetterTestUtils} from "../../util/VersionGetterTestUtils.sol";

import {Test} from "forge-std-1.9.6/src/Test.sol";
import {Vm} from "forge-std-1.9.6/src/Vm.sol";

contract QuorumFactoryTest is
    Test,
    ERC165Test,
    ConsensusTestUtils,
    VersionGetterTestUtils
{
    using LibAddressArray for address[];
    using LibAddressArray for Vm;
    using LibUint256Array for uint256[];
    using LibUint256Array for Vm;
    using LibConsensus for IQuorum;
    using LibTopic for address;
    using LibBytes for bytes;
    using LibClaim for Claim;

    IQuorumFactory _factory;
    bytes4[] _supportedInterfaces;

    function setUp() public {
        _factory = new QuorumFactory();
        _supportedInterfaces.push(type(IConsensus).interfaceId);
        _supportedInterfaces.push(type(IQuorum).interfaceId);
        _registerSupportedInterfaces(_supportedInterfaces);
    }

    function testVersion() external view {
        _testVersion(_factory);
    }

    function testNewQuorum(
        address[] memory validators,
        uint256 epochLength,
        uint256 claimStagingPeriod,
        bytes4 interfaceId
    ) public {
        vm.recordLogs();

        try _factory.newQuorum(validators, epochLength, claimStagingPeriod) returns (
            IQuorum quorum
        ) {
            Vm.Log[] memory logs = vm.getRecordedLogs();
            _testNewQuorumSuccess(
                validators, epochLength, claimStagingPeriod, interfaceId, quorum, logs
            );
        } catch (bytes memory error) {
            _testNewQuorumFailure(validators, epochLength, error);
            return;
        }
    }

    function testNewQuorumDeterministic(
        address[] memory validators,
        uint256 epochLength,
        uint256 claimStagingPeriod,
        bytes4 interfaceId,
        bytes32 salt
    ) public {
        address precalculatedAddress = _factory.calculateQuorumAddress(
            validators, epochLength, claimStagingPeriod, salt
        );

        vm.recordLogs();

        try _factory.newQuorum(
            validators, epochLength, claimStagingPeriod, salt
        ) returns (
            IQuorum quorum
        ) {
            Vm.Log[] memory logs = vm.getRecordedLogs();

            assertEq(
                precalculatedAddress,
                address(quorum),
                "calculateQuorumAddress(...) != newQuorum(...)"
            );

            _testNewQuorumSuccess(
                validators, epochLength, claimStagingPeriod, interfaceId, quorum, logs
            );
        } catch (bytes memory error) {
            _testNewQuorumFailure(validators, epochLength, error);
            return;
        }

        assertEq(
            _factory.calculateQuorumAddress(
                validators, epochLength, claimStagingPeriod, salt
            ),
            precalculatedAddress,
            "calculateQuorumAddress(...) is not a pure function"
        );

        // Cannot deploy an application with the same salt twice
        try _factory.newQuorum(validators, epochLength, claimStagingPeriod, salt) {
            revert("second deterministic deployment did not revert");
        } catch (bytes memory error) {
            assertEq(
                error,
                new bytes(0),
                "second deterministic deployment did not revert with empty error data"
            );
        }
    }

    function testSubmitClaimRevertsCallerIsNotValidator(
        address[] memory validators,
        uint256 epochLength,
        uint256 claimStagingPeriod,
        bool nonDeterministicDeployment,
        Claim memory claim
    ) external {
        IQuorum quorum = _newQuorum(
            validators, epochLength, claimStagingPeriod, nonDeterministicDeployment
        );

        claim.appContract = _newActiveAppMock();

        claim.lastProcessedBlockNumber = _randomEpochFinalBlockNumber(epochLength);
        vm.roll(_randomUintGt(claim.lastProcessedBlockNumber));

        claim.proof = _randomLeafProof();

        address caller = vm.randomAddressNotIn(validators);

        vm.expectRevert(_encodeCallerIsNotValidator(caller));
        vm.prank(caller); // non-validator address
        quorum.submitClaim(claim);
    }

    function testSubmitClaimRevertsNotEpochFinalBlock(
        address[] memory validators,
        uint256 epochLength,
        uint256 claimStagingPeriod,
        bool nonDeterministicDeployment,
        Claim memory claim
    ) external {
        uint256 lastProcessedBlockNumber = _randomNonEpochFinalBlock(epochLength);

        IQuorum quorum = _newQuorum(
            validators, epochLength, claimStagingPeriod, nonDeterministicDeployment
        );

        claim.appContract = _newActiveAppMock();

        claim.lastProcessedBlockNumber = lastProcessedBlockNumber;
        vm.roll(_randomUintGt(lastProcessedBlockNumber));

        claim.proof = _randomLeafProof();

        vm.expectRevert(_encodeNotEpochFinalBlock(lastProcessedBlockNumber, epochLength));
        vm.prank(vm.randomAddressIn(validators));
        quorum.submitClaim(claim);
    }

    function testSubmitClaimRevertNotPastBlock(
        address[] memory validators,
        uint256 epochLength,
        uint256 claimStagingPeriod,
        bool nonDeterministicDeployment,
        Claim memory claim
    ) external {
        IQuorum quorum = _newQuorum(
            validators, epochLength, claimStagingPeriod, nonDeterministicDeployment
        );

        claim.appContract = _newActiveAppMock();

        // Adjust the lastProcessedBlockNumber but do not roll past it.
        claim.lastProcessedBlockNumber = _randomEpochFinalBlockNumber(epochLength);

        claim.proof = _randomLeafProof();

        vm.expectRevert(_encodeNotPastBlock(claim.lastProcessedBlockNumber));
        vm.prank(vm.randomAddressIn(validators));
        quorum.submitClaim(claim);
    }

    function testSubmitClaimRevertApplicationNotDeployed(
        address[] memory validators,
        uint256 epochLength,
        uint256 claimStagingPeriod,
        bool nonDeterministicDeployment,
        Claim memory claim
    ) external {
        IQuorum quorum = _newQuorum(
            validators, epochLength, claimStagingPeriod, nonDeterministicDeployment
        );

        // We use a random account with no code as app contract
        claim.appContract = _randomAccountWithNoCode();

        claim.lastProcessedBlockNumber = _randomEpochFinalBlockNumber(epochLength);
        vm.roll(_randomUintGt(claim.lastProcessedBlockNumber));

        claim.proof = _randomLeafProof();

        vm.expectRevert(_encodeApplicationNotDeployed(claim.appContract));
        vm.prank(vm.randomAddressIn(validators));
        quorum.submitClaim(claim);
    }

    function testSubmitClaimRevertApplicationReverted(
        address[] memory validators,
        uint256 epochLength,
        uint256 claimStagingPeriod,
        bool nonDeterministicDeployment,
        Claim memory claim,
        bytes memory error
    ) external {
        IQuorum quorum = _newQuorum(
            validators, epochLength, claimStagingPeriod, nonDeterministicDeployment
        );

        // We make isForeclosed() revert with an error
        claim.appContract = _newAppMockReverts(error);

        claim.lastProcessedBlockNumber = _randomEpochFinalBlockNumber(epochLength);
        vm.roll(_randomUintGt(claim.lastProcessedBlockNumber));

        claim.proof = _randomLeafProof();

        vm.expectRevert(_encodeApplicationReverted(claim.appContract, error));
        vm.prank(vm.randomAddressIn(validators));
        quorum.submitClaim(claim);
    }

    function testSubmitClaimRevertApplicationReturnIllSizedReturnData(
        address[] memory validators,
        uint256 epochLength,
        uint256 claimStagingPeriod,
        bool nonDeterministicDeployment,
        Claim memory claim,
        bytes memory data
    ) external {
        // We make isForeclosed() return ill-sized data
        vm.assume(data.length != 32);

        IQuorum quorum = _newQuorum(
            validators, epochLength, claimStagingPeriod, nonDeterministicDeployment
        );

        claim.appContract = _newAppMockReturns(data);

        claim.lastProcessedBlockNumber = _randomEpochFinalBlockNumber(epochLength);
        vm.roll(_randomUintGt(claim.lastProcessedBlockNumber));

        claim.proof = _randomLeafProof();

        vm.expectRevert(_encodeIllformedApplicationReturnData(claim.appContract, data));
        vm.prank(vm.randomAddressIn(validators));
        quorum.submitClaim(claim);
    }

    function testSubmitClaimRevertApplicationReturnIllFormedReturnData(
        address[] memory validators,
        uint256 epochLength,
        uint256 claimStagingPeriod,
        bool nonDeterministicDeployment,
        Claim memory claim
    ) external {
        // We make isForeclosed() return an invalid boolean (neither 0 or 1)
        uint256 returnValue = vm.randomUint(2, type(uint256).max);

        IQuorum quorum = _newQuorum(
            validators, epochLength, claimStagingPeriod, nonDeterministicDeployment
        );

        bytes memory data = abi.encode(returnValue);
        claim.appContract = _newAppMockReturns(data);

        claim.lastProcessedBlockNumber = _randomEpochFinalBlockNumber(epochLength);
        vm.roll(_randomUintGt(claim.lastProcessedBlockNumber));

        claim.proof = _randomLeafProof();

        vm.expectRevert(_encodeIllformedApplicationReturnData(claim.appContract, data));
        vm.prank(vm.randomAddressIn(validators));
        quorum.submitClaim(claim);
    }

    function testSubmitClaimRevertApplicationForeclosed(
        address[] memory validators,
        uint256 epochLength,
        uint256 claimStagingPeriod,
        bool nonDeterministicDeployment,
        Claim memory claim
    ) external {
        IQuorum quorum = _newQuorum(
            validators, epochLength, claimStagingPeriod, nonDeterministicDeployment
        );

        // We make isForeclosed() return true
        claim.appContract = _newForeclosedAppMock();

        claim.lastProcessedBlockNumber = _randomEpochFinalBlockNumber(epochLength);
        vm.roll(_randomUintGt(claim.lastProcessedBlockNumber));

        claim.proof = _randomLeafProof();

        vm.expectRevert(_encodeApplicationForeclosed(claim.appContract));
        vm.prank(vm.randomAddressIn(validators));
        quorum.submitClaim(claim);
    }

    function testSubmitClaimRevertInvalidOutputsMerkleRootProofSize(
        address[] memory validators,
        uint256 epochLength,
        uint256 claimStagingPeriod,
        bool nonDeterministicDeployment,
        Claim memory claim
    ) external {
        IQuorum quorum = _newQuorum(
            validators, epochLength, claimStagingPeriod, nonDeterministicDeployment
        );

        claim.appContract = _newActiveAppMock();

        claim.lastProcessedBlockNumber = _randomEpochFinalBlockNumber(epochLength);
        vm.roll(_randomUintGt(claim.lastProcessedBlockNumber));

        claim.proof = _randomProof(_randomInvalidLeafProofSize());

        vm.expectRevert(_encodeInvalidOutputsMerkleRootProofSize(claim.proof.length));
        vm.prank(vm.randomAddressIn(validators));
        quorum.submitClaim(claim);
    }

    function testSubmitAndAcceptClaim(
        address[] memory validators,
        uint256 epochLength,
        uint256 claimStagingPeriod,
        bool nonDeterministicDeployment
    ) external {
        IQuorum quorum = _newQuorum(
            validators, epochLength, claimStagingPeriod, nonDeterministicDeployment
        );

        address appContract = address(new ApplicationForeclosureMock());

        address[] memory appContractSingleton = new address[](1);
        appContractSingleton[0] = appContract;

        uint256[] memory blockNumbers = _randomEpochFinalBlockNumbers(epochLength);

        bytes32 lastFinalizedMachineMerkleRoot;

        for (uint256 claimIndex; claimIndex < blockNumbers.length; ++claimIndex) {
            uint256 lastProcessedBlockNumber = blockNumbers[claimIndex];
            bool wasEpochStaged =
                blockNumbers.containsBefore(lastProcessedBlockNumber, claimIndex);

            Claim memory winningClaim = Claim({
                appContract: appContract,
                lastProcessedBlockNumber: lastProcessedBlockNumber,
                outputsMerkleRoot: _randomBytes32(),
                proof: _randomLeafProof()
            });

            bytes32 winningMachineMerkleRoot = winningClaim.computeMachineMerkleRoot();

            // Divide validators into three categories:
            // - winners: they form a majority and vote on the same claim
            // - losers: they form a minority and vote on other claims
            // - non-voters: they also form a minority, but do not vote
            uint256 numOfValidators = quorum.numOfValidators();
            uint256 majority = 1 + (numOfValidators / 2);
            uint256 numOfWinners = vm.randomUint(majority, numOfValidators);
            uint256 numOfNonWinners = numOfValidators - numOfWinners;
            uint256 numOfLosers = vm.randomUint(0, numOfNonWinners);
            uint256 numOfNonVoters = numOfNonWinners - numOfLosers;

            // Check relations between categories
            assertEq(numOfValidators, numOfWinners + numOfLosers + numOfNonVoters);
            assertEq(numOfNonWinners, numOfLosers + numOfNonVoters);
            assertGt(numOfWinners, numOfNonWinners);

            // List validator IDs and shuffle them
            uint256[] memory ids = LibUint256Array.sequence(1, numOfValidators);
            vm.shuffleInPlace(ids);
            assertEq(ids.length, numOfValidators);

            // Distribute validators between categories
            uint256[] memory winnerIds;
            uint256[] memory loserIds;
            uint256[] memory nonVoterIds;

            {
                uint256[] memory nonWinnerIds;

                (winnerIds, nonWinnerIds) = ids.split(numOfWinners);
                (loserIds, nonVoterIds) = nonWinnerIds.split(numOfLosers);

                // Check lengths of ID arrays
                // and number of validators in each category
                assertEq(winnerIds.length, numOfWinners);
                assertEq(nonWinnerIds.length, numOfNonWinners);
                assertEq(loserIds.length, numOfLosers);
                assertEq(nonVoterIds.length, numOfNonVoters);
            }

            if (wasEpochStaged) {
                assertGe(
                    quorum.numOfValidatorsInFavorOfAnyClaimInEpoch(
                        appContract, lastProcessedBlockNumber
                    ),
                    majority,
                    "Expected a majority of validators to be in favor of any claim in epoch"
                );
            } else {
                assertEq(
                    quorum.numOfValidatorsInFavorOfAnyClaimInEpoch(
                        appContract, lastProcessedBlockNumber
                    ),
                    0,
                    "Expected no validator to be in favor of any claim in epoch"
                );
                assertEq(
                    quorum.numOfValidatorsInFavorOf(
                        appContract, lastProcessedBlockNumber, winningMachineMerkleRoot
                    ),
                    0,
                    "Expected no validator to be in favor of the winning claim in epoch"
                );
                assertEq(
                    quorum.numOfValidatorsInFavorOf(
                        appContract, lastProcessedBlockNumber, _randomBytes32()
                    ),
                    0,
                    "Expected no validator to be in favor of any random claim in epoch"
                );
            }

            // If behind last-processed block number, roll past it
            if (vm.getBlockNumber() <= lastProcessedBlockNumber) {
                vm.roll(_randomUintGt(lastProcessedBlockNumber));
            }

            uint256 numOfWinningVotes;
            uint256 numOfLosingVotes;

            for (uint256 i; i < ids.length; ++i) {
                uint256 id = ids[i];

                if (!wasEpochStaged) {
                    assertFalse(
                        quorum.isValidatorInFavorOfAnyClaimInEpoch(
                            appContract, lastProcessedBlockNumber, id
                        ),
                        "Expected validator to not be in favor of any claim in epoch"
                    );
                    assertFalse(
                        quorum.isValidatorInFavorOf(
                            appContract, lastProcessedBlockNumber, _randomBytes32(), id
                        ),
                        "Expected validator to not be in favor of any random claim in epoch"
                    );
                }

                if (nonVoterIds.contains(id)) {
                    continue; // skip voting
                }

                Claim memory claim;
                bytes32 machineMerkleRoot;

                if (winnerIds.contains(id)) {
                    (claim, machineMerkleRoot) = (winningClaim, winningMachineMerkleRoot);
                    ++numOfWinningVotes;
                } else if (loserIds.contains(id)) {
                    (claim, machineMerkleRoot) =
                        _randomClaimDifferentFrom(winningClaim, winningMachineMerkleRoot);
                    ++numOfLosingVotes;
                } else {
                    revert("unexpected validator category");
                }

                if (!wasEpochStaged) {
                    assertFalse(
                        quorum.isValidatorInFavorOf(
                            appContract, lastProcessedBlockNumber, machineMerkleRoot, id
                        ),
                        "Expected validator to not be in favor of claim"
                    );
                }

                uint256 totalNumOfSubmittedClaimsBefore =
                    quorum.getNumberOfSubmittedClaims(appContract);
                uint256 totalNumOfStagedClaimsBefore =
                    quorum.getNumberOfStagedClaims(appContract);
                uint256 totalNumOfAcceptedClaimsBefore =
                    quorum.getNumberOfAcceptedClaims(appContract);

                uint256 numOfValidatorsInFavorOfAnyClaimInEpochBefore =
                    quorum.numOfValidatorsInFavorOfAnyClaimInEpoch(
                        appContract, lastProcessedBlockNumber
                    );

                uint256 numOfValidatorsInFavorOfClaimBefore =
                    quorum.numOfValidatorsInFavorOf(
                        appContract, lastProcessedBlockNumber, machineMerkleRoot
                    );

                address validator = quorum.validatorById(id);
                assertTrue(validators.contains(validator), "voter is not validator");

                try this.simulateForeclosureAndClaimSubmission(quorum, validator, claim) {
                    revert("expected simulation to revert");
                } catch (bytes memory error) {
                    (bytes4 errorSelector, bytes memory errorArgs) = error.consumeBytes4();
                    if (errorSelector == IConsensus.NotFirstClaim.selector) {
                        (address arg1, uint256 arg2) =
                            abi.decode(errorArgs, (address, uint256));
                        assertEq(
                            arg1, appContract, "NotFirstClaim.appContract != appContract"
                        );
                        assertEq(
                            arg2,
                            lastProcessedBlockNumber,
                            "NotFirstClaim.lastProcessedBlockNumber != lastProcessedBlockNumber"
                        );
                        assertTrue(
                            wasEpochStaged,
                            "NotFirstClaim should only be raised if epoch was already staged"
                        );
                        assertTrue(
                            quorum.isValidatorInFavorOfAnyClaimInEpoch(
                                appContract, lastProcessedBlockNumber, id
                            ),
                            "Expected isValidatorInFavorOfAnyClaimInEpoch(...) to return true after NotFirstClaim"
                        );
                        assertFalse(
                            quorum.isValidatorInFavorOf(
                                appContract,
                                lastProcessedBlockNumber,
                                machineMerkleRoot,
                                id
                            ),
                            "Expected isValidatorInFavorOf(...) to return false after NotFirstClaim"
                        );
                    } else if (
                        errorSelector
                            == IApplicationChecker.ApplicationForeclosed.selector
                    ) {
                        (address arg1) = abi.decode(errorArgs, (address));
                        assertEq(
                            arg1,
                            appContract,
                            "ApplicationForeclosed.appContract != appContract"
                        );
                    } else {
                        revert("Unexpected error");
                    }
                }

                vm.recordLogs();

                vm.prank(validator);
                try quorum.submitClaim(
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
                        assertEq(
                            arg1,
                            claim.appContract,
                            "NotFirstClaim.appContract != appContract"
                        );
                        assertEq(
                            arg2,
                            claim.lastProcessedBlockNumber,
                            "NotFirstClaim.lastProcessedBlockNumber != lastProcessedBlockNumber"
                        );
                        assertTrue(
                            wasEpochStaged,
                            "NotFirstClaim should only be raised if epoch was already staged"
                        );
                        assertTrue(
                            quorum.isValidatorInFavorOfAnyClaimInEpoch(
                                claim.appContract, claim.lastProcessedBlockNumber, id
                            ),
                            "Expected isValidatorInFavorOfAnyClaimInEpoch(...) to return true after NotFirstClaim"
                        );
                        assertFalse(
                            quorum.isValidatorInFavorOf(
                                claim.appContract,
                                claim.lastProcessedBlockNumber,
                                machineMerkleRoot,
                                id
                            ),
                            "Expected isValidatorInFavorOf(...) to return false after NotFirstClaim"
                        );
                    } else {
                        revert("Unexpected error");
                    }

                    // Proceed to the next claim.
                    continue;
                }

                Vm.Log[] memory logs = vm.getRecordedLogs();

                uint256 numOfClaimSubmittedEvents;
                uint256 numOfClaimStagedEvents;

                for (uint256 j; j < logs.length; ++j) {
                    Vm.Log memory log = logs[j];
                    if (log.emitter == address(quorum)) {
                        assertGe(log.topics.length, 1, "unexpected annonymous event");
                        bytes32 topic0 = log.topics[0];
                        if (topic0 == IConsensus.ClaimSubmitted.selector) {
                            (uint256 arg0, bytes32 arg1, bytes32 arg2) =
                                abi.decode(log.data, (uint256, bytes32, bytes32));
                            assertEq(log.topics[1], validator.asTopic());
                            assertEq(log.topics[2], appContract.asTopic());
                            assertEq(arg0, lastProcessedBlockNumber);
                            assertEq(arg1, claim.outputsMerkleRoot);
                            assertEq(arg2, machineMerkleRoot);
                            ++numOfClaimSubmittedEvents;
                        } else if (topic0 == IConsensus.ClaimStaged.selector) {
                            (uint256 arg0, bytes32 arg1, bytes32 arg2) =
                                abi.decode(log.data, (uint256, bytes32, bytes32));
                            assertEq(log.topics[1], appContract.asTopic());
                            assertEq(arg0, lastProcessedBlockNumber);
                            assertEq(arg1, claim.outputsMerkleRoot);
                            assertEq(arg2, machineMerkleRoot);
                            ++numOfClaimStagedEvents;
                        } else {
                            revert("unexpected event selector");
                        }
                    } else {
                        revert("unexpected log emitter");
                    }
                }

                assertEq(numOfClaimSubmittedEvents, 1, "expected 1 ClaimSubmitted event");

                IConsensus.Claim memory submittedClaim = quorum.getClaim(
                    appContract, lastProcessedBlockNumber, machineMerkleRoot
                );

                if (wasEpochStaged) {
                    assertEq(numOfClaimStagedEvents, 0, "expected 0 ClaimStaged events");
                } else {
                    if (machineMerkleRoot == winningMachineMerkleRoot) {
                        assertEq(
                            numOfClaimStagedEvents,
                            (numOfWinningVotes == majority) ? 1 : 0,
                            "expected 1 ClaimStaged event if claim just reached majority"
                        );
                        assertEq(
                            uint256(submittedClaim.status),
                            uint256(
                                (numOfWinningVotes >= majority)
                                    ? IConsensus.ClaimStatus.STAGED
                                    : IConsensus.ClaimStatus.UNSTAGED
                            ),
                            "expected claim to be staged if claim reached majority"
                        );
                    } else {
                        assertEq(
                            numOfClaimStagedEvents, 0, "expected 0 ClaimStaged events"
                        );
                        assertEq(
                            uint256(submittedClaim.status),
                            uint256(IConsensus.ClaimStatus.UNSTAGED),
                            "expected claim to be unstaged"
                        );
                    }
                }

                if (
                    submittedClaim.status == IConsensus.ClaimStatus.STAGED
                        || submittedClaim.status == IConsensus.ClaimStatus.ACCEPTED
                ) {
                    assertEq(
                        submittedClaim.stagedOutputsMerkleRoot,
                        claim.outputsMerkleRoot,
                        "expected outputs Merkle root to be staged"
                    );
                }

                if (submittedClaim.status == IConsensus.ClaimStatus.ACCEPTED) {
                    assertLe(
                        submittedClaim.stagingBlockNumber + claimStagingPeriod,
                        vm.getBlockNumber(),
                        "expected claim staging period to have elapsed"
                    );
                    assertTrue(
                        quorum.isOutputsMerkleRootValid(claim),
                        "expected accepted outputs Merkle root to be valid"
                    );
                }

                assertEq(
                    quorum.getLastFinalizedMachineMerkleRoot(claim.appContract),
                    lastFinalizedMachineMerkleRoot,
                    "Check last finalized machine Merkle root"
                );

                assertEq(
                    quorum.getNumberOfSubmittedClaims(appContract),
                    totalNumOfSubmittedClaimsBefore + numOfClaimSubmittedEvents,
                    "Total number of submitted claims should be increased by number of events"
                );

                assertEq(
                    quorum.getNumberOfStagedClaims(appContract),
                    totalNumOfStagedClaimsBefore + numOfClaimStagedEvents,
                    "Total number of staged claims should be increased by number of events"
                );

                assertEq(
                    quorum.getNumberOfAcceptedClaims(appContract),
                    totalNumOfAcceptedClaimsBefore,
                    "Total number of accepted claims should remain the same"
                );

                address notAppContract = vm.randomAddressNotIn(appContractSingleton);

                assertEq(
                    quorum.getNumberOfSubmittedClaims(notAppContract),
                    0,
                    "Total number of submitted claims should be zero for other apps"
                );

                assertEq(
                    quorum.getNumberOfStagedClaims(notAppContract),
                    0,
                    "Total number of staged claims should be zero for other apps"
                );

                assertEq(
                    quorum.getNumberOfAcceptedClaims(notAppContract),
                    0,
                    "Total number of accepted claims should be zero for other apps"
                );

                assertEq(
                    quorum.numOfValidatorsInFavorOfAnyClaimInEpoch(
                        appContract, lastProcessedBlockNumber
                    ),
                    numOfValidatorsInFavorOfAnyClaimInEpochBefore + 1,
                    "Number of validators in favor of any claim in epoch should be incremented"
                );

                assertEq(
                    quorum.numOfValidatorsInFavorOfAnyClaimInEpoch(
                        notAppContract, lastProcessedBlockNumber
                    ),
                    0,
                    "Number of validators in favor of any claim in epoch should be zero for other apps"
                );

                assertTrue(
                    quorum.isValidatorInFavorOfAnyClaimInEpoch(
                        appContract, lastProcessedBlockNumber, id
                    ),
                    "Expected validator to be in favor of any claim in epoch"
                );

                assertFalse(
                    quorum.isValidatorInFavorOfAnyClaimInEpoch(
                        notAppContract, lastProcessedBlockNumber, id
                    ),
                    "Validator shouldn't be in favor of any claim in epoch for other apps"
                );

                assertEq(
                    quorum.numOfValidatorsInFavorOf(
                        appContract, lastProcessedBlockNumber, machineMerkleRoot
                    ),
                    numOfValidatorsInFavorOfClaimBefore + 1,
                    "Number of validators in favor of claim should be incremented"
                );

                assertEq(
                    quorum.numOfValidatorsInFavorOf(
                        notAppContract, lastProcessedBlockNumber, machineMerkleRoot
                    ),
                    0,
                    "Number of validators in favor of claim should be zero for other apps"
                );

                assertTrue(
                    quorum.isValidatorInFavorOf(
                        appContract, lastProcessedBlockNumber, machineMerkleRoot, id
                    ),
                    "Expected validator to be in favor of claim"
                );

                assertFalse(
                    quorum.isValidatorInFavorOf(
                        notAppContract, lastProcessedBlockNumber, machineMerkleRoot, id
                    ),
                    "Validator shouldn't be in favor of claim for other apps"
                );

                vm.recordLogs();

                vm.prank(validator);
                quorum.submitClaim(claim);

                assertEq(
                    vm.getRecordedLogs().length,
                    0,
                    "submitClaim() expected to emit 0 events on subsequent call"
                );

                assertEq(
                    quorum.numOfValidatorsInFavorOfAnyClaimInEpoch(
                        appContract, lastProcessedBlockNumber
                    ),
                    numOfValidatorsInFavorOfAnyClaimInEpochBefore + 1,
                    "Number of validators in favor of any claim in epoch should be incremented"
                );

                assertTrue(
                    quorum.isValidatorInFavorOfAnyClaimInEpoch(
                        appContract, lastProcessedBlockNumber, id
                    ),
                    "Expected validator to be in favor of any claim in epoch"
                );

                assertEq(
                    quorum.numOfValidatorsInFavorOf(
                        appContract, lastProcessedBlockNumber, machineMerkleRoot
                    ),
                    numOfValidatorsInFavorOfClaimBefore + 1,
                    "Number of validators in favor of claim should be incremented"
                );

                assertTrue(
                    quorum.isValidatorInFavorOf(
                        appContract, lastProcessedBlockNumber, machineMerkleRoot, id
                    ),
                    "Expected validator to be in favor of claim"
                );
            }

            if (!wasEpochStaged) {
                IConsensus.Claim memory stagedClaim = quorum.getClaim(
                    appContract, lastProcessedBlockNumber, winningMachineMerkleRoot
                );

                assertEq(
                    uint256(stagedClaim.status),
                    uint256(IConsensus.ClaimStatus.STAGED),
                    "Expected winning claim to be staged"
                );

                assertEq(
                    stagedClaim.stagedOutputsMerkleRoot,
                    winningClaim.outputsMerkleRoot,
                    "Expected winning outputs Merkle root to be staged"
                );

                if (claimStagingPeriod >= 1) {
                    vm.roll(
                        vm.randomUint(
                            vm.getBlockNumber(),
                            _boundedSum(
                                stagedClaim.stagingBlockNumber, claimStagingPeriod - 1
                            )
                        )
                    );

                    uint256 numberOfBlocksAfterStaging =
                        vm.getBlockNumber() - stagedClaim.stagingBlockNumber;

                    vm.expectRevert(
                        _encodeClaimStagingPeriodNotOverYet(
                            appContract,
                            lastProcessedBlockNumber,
                            winningMachineMerkleRoot,
                            numberOfBlocksAfterStaging,
                            claimStagingPeriod
                        )
                    );
                    vm.prank(vm.randomAddress());
                    quorum.acceptClaim(
                        appContract, lastProcessedBlockNumber, winningMachineMerkleRoot
                    );
                }

                // skip acceptance because cannot roll past claim staging period
                if (
                    stagedClaim.stagingBlockNumber
                        > type(uint256).max - claimStagingPeriod
                ) {
                    continue;
                }

                vm.roll(
                    vm.randomUint(
                        stagedClaim.stagingBlockNumber + claimStagingPeriod,
                        type(uint256).max
                    )
                );

                assertLe(
                    stagedClaim.stagingBlockNumber + claimStagingPeriod,
                    vm.getBlockNumber(),
                    "Expected to be past claim staging period"
                );

                uint256 totalNumOfSubmittedClaimsBefore =
                    quorum.getNumberOfSubmittedClaims(appContract);
                uint256 totalNumOfStagedClaimsBefore =
                    quorum.getNumberOfStagedClaims(appContract);
                uint256 totalNumOfAcceptedClaimsBefore =
                    quorum.getNumberOfAcceptedClaims(appContract);

                vm.expectRevert(_encodeApplicationForeclosed(appContract));
                this.simulateForeclosureAndClaimAcceptance(quorum, winningClaim);

                vm.recordLogs();

                vm.prank(vm.randomAddress());
                quorum.acceptClaim(
                    appContract, lastProcessedBlockNumber, winningMachineMerkleRoot
                );

                Vm.Log[] memory logs = vm.getRecordedLogs();

                uint256 numOfClaimAcceptedEvents;

                for (uint256 i; i < logs.length; ++i) {
                    Vm.Log memory log = logs[i];
                    if (log.emitter == address(quorum)) {
                        assertGe(log.topics.length, 1, "unexpected annonymous event");
                        bytes32 topic0 = log.topics[0];
                        if (topic0 == IConsensus.ClaimAccepted.selector) {
                            (uint256 arg0, bytes32 arg1, bytes32 arg2) =
                                abi.decode(log.data, (uint256, bytes32, bytes32));
                            assertEq(log.topics[1], appContract.asTopic());
                            assertEq(arg0, lastProcessedBlockNumber);
                            assertEq(arg1, winningClaim.outputsMerkleRoot);
                            assertEq(arg2, winningMachineMerkleRoot);
                            ++numOfClaimAcceptedEvents;
                        } else {
                            revert("unexpected event selector");
                        }
                    } else {
                        revert("unexpected log emitter");
                    }
                }

                assertEq(numOfClaimAcceptedEvents, 1, "expected 1 ClaimAccepted event");

                assertEq(
                    quorum.getNumberOfSubmittedClaims(appContract),
                    totalNumOfSubmittedClaimsBefore,
                    "Total number of submitted claims should remain the same"
                );

                assertEq(
                    quorum.getNumberOfStagedClaims(appContract),
                    totalNumOfStagedClaimsBefore,
                    "Total number of staged claims should remain the same"
                );

                assertEq(
                    quorum.getNumberOfAcceptedClaims(appContract),
                    totalNumOfAcceptedClaimsBefore + numOfClaimAcceptedEvents,
                    "Total number of accepted claims should be increased by number of events"
                );

                IConsensus.Claim memory acceptedClaim = quorum.getClaim(
                    appContract, lastProcessedBlockNumber, winningMachineMerkleRoot
                );

                assertEq(
                    uint256(acceptedClaim.status),
                    uint256(IConsensus.ClaimStatus.ACCEPTED),
                    "Expected winning claim to be accepted"
                );

                assertEq(
                    acceptedClaim.stagedOutputsMerkleRoot,
                    winningClaim.outputsMerkleRoot,
                    "Expected winning outputs Merkle root to be accepted"
                );

                assertLe(
                    acceptedClaim.stagingBlockNumber + claimStagingPeriod,
                    vm.getBlockNumber(),
                    "Expected accepted claim staging period to have elapsed"
                );

                assertEq(
                    numOfWinningVotes, numOfWinners, "# winning votes == # winner voters"
                );
                assertEq(
                    numOfLosingVotes, numOfLosers, "# losing votes == # loser voters"
                );
                assertTrue(
                    quorum.isOutputsMerkleRootValid(winningClaim),
                    "The outputs Merkle root should be valid"
                );

                assertEq(
                    quorum.numOfValidatorsInFavorOfAnyClaimInEpoch(
                        appContract, lastProcessedBlockNumber
                    ),
                    numOfWinningVotes + numOfLosingVotes,
                    "numOfValidatorsInFavorOfAnyClaimInEpoch(...) == # winning votes + # losing votes"
                );

                assertEq(
                    quorum.numOfValidatorsInFavorOf(
                        appContract, lastProcessedBlockNumber, winningMachineMerkleRoot
                    ),
                    numOfWinningVotes,
                    "numOfValidatorsInFavorOf(winningClaim...) = # winning votes"
                );

                vm.expectRevert(
                    _encodeClaimNotStaged(
                        appContract,
                        lastProcessedBlockNumber,
                        winningMachineMerkleRoot,
                        IConsensus.ClaimStatus.ACCEPTED
                    )
                );
                vm.prank(vm.randomAddress());
                quorum.acceptClaim(
                    appContract, lastProcessedBlockNumber, winningMachineMerkleRoot
                );

                (bool isEmpty, uint256 max) = blockNumbers.maxBefore(claimIndex);

                // If the claim was successful submitted, then its last processed
                // block number cannot be equal to any past successful claim.
                if (isEmpty || lastProcessedBlockNumber > max) {
                    lastFinalizedMachineMerkleRoot = winningMachineMerkleRoot;
                }
            }
        }
    }

    function testAcceptClaimRevertApplicationNotDeployed(
        address[] memory validators,
        uint256 epochLength,
        uint256 claimStagingPeriod,
        bool nonDeterministicDeployment,
        bytes32 machineMerkleRoot
    ) external {
        IQuorum quorum = _newQuorum(
            validators, epochLength, claimStagingPeriod, nonDeterministicDeployment
        );

        // We use a random account with no code as app contract
        address appContract = _randomAccountWithNoCode();

        uint256 lastProcessedBlockNumber = _randomEpochFinalBlockNumber(epochLength);
        vm.roll(_randomUintGt(lastProcessedBlockNumber));

        vm.expectRevert(_encodeApplicationNotDeployed(appContract));
        vm.prank(vm.randomAddress());
        quorum.acceptClaim(appContract, lastProcessedBlockNumber, machineMerkleRoot);
    }

    function testAcceptClaimRevertApplicationReverted(
        address[] memory validators,
        uint256 epochLength,
        uint256 claimStagingPeriod,
        bool nonDeterministicDeployment,
        bytes32 machineMerkleRoot,
        bytes memory error
    ) external {
        IQuorum quorum = _newQuorum(
            validators, epochLength, claimStagingPeriod, nonDeterministicDeployment
        );

        // We make isForeclosed() revert with an error
        address appContract = _newAppMockReverts(error);

        uint256 lastProcessedBlockNumber = _randomEpochFinalBlockNumber(epochLength);
        vm.roll(_randomUintGt(lastProcessedBlockNumber));

        vm.expectRevert(_encodeApplicationReverted(appContract, error));
        vm.prank(vm.randomAddress());
        quorum.acceptClaim(appContract, lastProcessedBlockNumber, machineMerkleRoot);
    }

    function testAcceptClaimRevertApplicationReturnIllSizedReturnData(
        address[] memory validators,
        uint256 epochLength,
        uint256 claimStagingPeriod,
        bool nonDeterministicDeployment,
        bytes32 machineMerkleRoot,
        bytes memory data
    ) external {
        // We make isForeclosed() return ill-sized data
        vm.assume(data.length != 32);

        IQuorum quorum = _newQuorum(
            validators, epochLength, claimStagingPeriod, nonDeterministicDeployment
        );

        address appContract = _newAppMockReturns(data);

        uint256 lastProcessedBlockNumber = _randomEpochFinalBlockNumber(epochLength);
        vm.roll(_randomUintGt(lastProcessedBlockNumber));

        vm.expectRevert(_encodeIllformedApplicationReturnData(appContract, data));
        vm.prank(vm.randomAddress());
        quorum.acceptClaim(appContract, lastProcessedBlockNumber, machineMerkleRoot);
    }

    function testAcceptClaimRevertApplicationReturnIllFormedReturnData(
        address[] memory validators,
        uint256 epochLength,
        uint256 claimStagingPeriod,
        bool nonDeterministicDeployment,
        bytes32 machineMerkleRoot
    ) external {
        // We make isForeclosed() return an invalid boolean (neither 0 or 1)
        uint256 returnValue = vm.randomUint(2, type(uint256).max);

        IQuorum quorum = _newQuorum(
            validators, epochLength, claimStagingPeriod, nonDeterministicDeployment
        );

        bytes memory data = abi.encode(returnValue);
        address appContract = _newAppMockReturns(data);

        uint256 lastProcessedBlockNumber = _randomEpochFinalBlockNumber(epochLength);
        vm.roll(_randomUintGt(lastProcessedBlockNumber));

        vm.expectRevert(_encodeIllformedApplicationReturnData(appContract, data));
        vm.prank(vm.randomAddress());
        quorum.acceptClaim(appContract, lastProcessedBlockNumber, machineMerkleRoot);
    }

    function testAcceptClaimRevertApplicationForeclosed(
        address[] memory validators,
        uint256 epochLength,
        uint256 claimStagingPeriod,
        bool nonDeterministicDeployment,
        bytes32 machineMerkleRoot
    ) external {
        IQuorum quorum = _newQuorum(
            validators, epochLength, claimStagingPeriod, nonDeterministicDeployment
        );

        address appContract = _newForeclosedAppMock();

        uint256 lastProcessedBlockNumber = _randomEpochFinalBlockNumber(epochLength);
        vm.roll(_randomUintGt(lastProcessedBlockNumber));

        vm.expectRevert(_encodeApplicationForeclosed(appContract));
        vm.prank(vm.randomAddress());
        quorum.acceptClaim(appContract, lastProcessedBlockNumber, machineMerkleRoot);
    }

    function testAcceptClaimRevertsNotEpochFinalBlock(
        address[] memory validators,
        uint256 epochLength,
        uint256 claimStagingPeriod,
        bool nonDeterministicDeployment,
        bytes32 machineMerkleRoot
    ) external {
        IQuorum quorum = _newQuorum(
            validators, epochLength, claimStagingPeriod, nonDeterministicDeployment
        );

        address appContract = _newActiveAppMock();

        uint256 lastProcessedBlockNumber = _randomNonEpochFinalBlock(epochLength);
        vm.roll(_randomUintGt(lastProcessedBlockNumber));

        vm.expectRevert(_encodeNotEpochFinalBlock(lastProcessedBlockNumber, epochLength));
        vm.prank(vm.randomAddress());
        quorum.acceptClaim(appContract, lastProcessedBlockNumber, machineMerkleRoot);
    }

    function testAcceptClaimRevertsNotPastBlock(
        address[] memory validators,
        uint256 epochLength,
        uint256 claimStagingPeriod,
        bool nonDeterministicDeployment,
        bytes32 machineMerkleRoot
    ) external {
        IQuorum quorum = _newQuorum(
            validators, epochLength, claimStagingPeriod, nonDeterministicDeployment
        );

        address appContract = _newActiveAppMock();

        // Adjust the lastProcessedBlockNumber but do not roll past it.
        uint256 lastProcessedBlockNumber = _randomEpochFinalBlockNumber(epochLength);

        vm.expectRevert(_encodeNotPastBlock(lastProcessedBlockNumber));
        vm.prank(vm.randomAddress());
        quorum.acceptClaim(appContract, lastProcessedBlockNumber, machineMerkleRoot);
    }

    function testAcceptClaimRevertsUnstagedClaim(
        address[] memory validators,
        uint256 epochLength,
        uint256 claimStagingPeriod,
        bool nonDeterministicDeployment,
        bytes32 machineMerkleRoot
    ) external {
        IQuorum quorum = _newQuorum(
            validators, epochLength, claimStagingPeriod, nonDeterministicDeployment
        );

        address appContract = _newActiveAppMock();

        uint256 lastProcessedBlockNumber = _randomEpochFinalBlockNumber(epochLength);
        vm.roll(_randomUintGt(lastProcessedBlockNumber));

        vm.expectRevert(
            _encodeClaimNotStaged(
                appContract,
                lastProcessedBlockNumber,
                machineMerkleRoot,
                IConsensus.ClaimStatus.UNSTAGED
            )
        );
        vm.prank(vm.randomAddress());
        quorum.acceptClaim(appContract, lastProcessedBlockNumber, machineMerkleRoot);
    }

    function _testNewQuorumSuccess(
        address[] memory validators,
        uint256 epochLength,
        uint256 claimStagingPeriod,
        bytes4 interfaceId,
        IQuorum quorum,
        Vm.Log[] memory logs
    ) internal {
        uint256 numOfQuorumCreated;

        for (uint256 i; i < logs.length; ++i) {
            Vm.Log memory log = logs[i];
            if (log.emitter == address(_factory)) {
                bytes32 topic0 = log.topics[0];
                if (topic0 == IQuorumFactory.QuorumCreated.selector) {
                    ++numOfQuorumCreated;
                    address quorumAddress = abi.decode(log.data, (address));
                    assertEq(quorumAddress, address(quorum));
                } else {
                    revert("unexpected log topic #0");
                }
            } else {
                revert("unexpected log");
            }
        }

        assertEq(numOfQuorumCreated, 1, "number of QuorumCreated events");

        _testVersion(quorum);

        uint256 numOfValidators = quorum.numOfValidators();
        assertGt(numOfValidators, 0, "numOfValidators() > 0");

        assertEq(quorum.getEpochLength(), epochLength, "getEpochLength() == epochLength");
        assertGt(epochLength, 0, "getEpochLength() > 0");

        assertEq(
            quorum.getClaimStagingPeriod(),
            claimStagingPeriod,
            "getClaimStagingPeriod() == claimStagingPeriod"
        );

        assertLe(
            numOfValidators,
            validators.length,
            "Number of unique validators <= number of validators"
        );

        // We first check that every validator in the validators array
        // has a unique ID and that this ID is assigned to them.
        for (uint256 i; i < validators.length; ++i) {
            address validator = validators[i];
            assertNotEq(validator, address(0), "Validators should be != address(0)");
            uint256 id = quorum.validatorId(validator);
            assertGe(id, 1, "Validator ID should be >= 1");
            assertLe(id, numOfValidators, "Validator ID should be <= numOfValidators");
            assertEq(quorum.validatorById(id), validator, "Validator by ID should match");
        }

        // Then we check that every ID is assigned to a validator in the array.
        // By the pidgenhole principle, this can already be assumed if the
        // number of unique validators is less than or equal to the length
        // of the original array. Nevertheless, we test this for redundancy.
        for (uint256 id = 1; id <= numOfValidators; ++id) {
            address validator = quorum.validatorById(id);
            bool isValidatorInArray = false;
            for (uint256 i; i < validators.length; ++i) {
                if (validator == validators[i]) {
                    isValidatorInArray = true;
                    break;
                }
            }
            assertTrue(isValidatorInArray, "Validator not in array");
        }

        // We check that zero address and zero ID map to each other.
        assertEq(quorum.validatorId(address(0)), 0, "validatorId(address(0)) == 0");
        assertEq(quorum.validatorById(0), address(0), "validatorById(0) == address(0)");

        // We check that non-validators are assigned ID zero.
        assertEq(
            quorum.validatorId(vm.randomAddressNotIn(validators)),
            0,
            "for any non-validator addr, validatorId(addr) == 0"
        );

        // We check that invalid IDs map to the zero address.
        assertEq(
            quorum.validatorById(vm.randomUint(numOfValidators + 1, type(uint256).max)),
            address(0),
            "for any id > numOfValidators(), validatorById(id) == address(0)"
        );

        // We check that initially all outputs Merkle roots are invalid.
        assertFalse(
            quorum.isOutputsMerkleRootValid(vm.randomAddress(), _randomBytes32()),
            "initially, isOutputsMerkleRootValid(...) == false"
        );

        // We check that initially no machine Merkle root has been finalized.
        assertEq(
            quorum.getLastFinalizedMachineMerkleRoot(vm.randomAddress()),
            bytes32(0),
            "initially, getLastFinalizedMachineMerkleRoot(...) == bytes32(0)"
        );

        // We check that initially no validator is in favor of any claim in an epoch.
        assertEq(
            quorum.numOfValidatorsInFavorOfAnyClaimInEpoch(
                vm.randomAddress(), vm.randomUint()
            ),
            0,
            "initially, numOfValidatorsInFavorOfAnyClaimInEpoch(...) == 0"
        );
        assertEq(
            quorum.numOfValidatorsInFavorOf(
                vm.randomAddress(), vm.randomUint(), _randomBytes32()
            ),
            0,
            "initially, numOfValidatorsInFavorOf(...) == 0"
        );
        assertFalse(
            quorum.isValidatorInFavorOfAnyClaimInEpoch(
                vm.randomAddress(), vm.randomUint(), vm.randomUint()
            ),
            "initially, isValidatorInFavorOfAnyClaimInEpoch(...) == false"
        );
        assertFalse(
            quorum.isValidatorInFavorOf(
                vm.randomAddress(), vm.randomUint(), _randomBytes32(), vm.randomUint()
            ),
            "initially, isValidatorInFavorOf(...) == false"
        );

        // We check that initially no claim is staged.
        assertEq(
            uint256(
                quorum.getClaim(vm.randomAddress(), vm.randomUint(), _randomBytes32())
                .status
            ),
            uint256(IConsensus.ClaimStatus.UNSTAGED),
            "initially, getClaim(...).status == ClaimStatus.UNSTAGED"
        );

        // Also, initially, no `ClaimSubmitted`, `ClaimStaged` or `ClaimAccepted` were emitted.
        assertEq(
            quorum.getNumberOfSubmittedClaims(vm.randomAddress()),
            0,
            "initially, getNumberOfSubmittedClaims(...) == 0"
        );
        assertEq(
            quorum.getNumberOfStagedClaims(vm.randomAddress()),
            0,
            "initially, getNumberOfStagedClaims(...) == 0"
        );
        assertEq(
            quorum.getNumberOfAcceptedClaims(vm.randomAddress()),
            0,
            "initially, getNumberOfAcceptedClaims(...) == 0"
        );

        // Test ERC-165 interface
        _testSupportsInterface(quorum, interfaceId);
    }

    function _testNewQuorumFailure(
        address[] memory validators,
        uint256 epochLength,
        bytes memory error
    ) internal pure {
        (bytes4 errorSelector, bytes memory errorArgs) = error.consumeBytes4();
        if (errorSelector == IQuorumFactoryErrors.ZeroAddressValidator.selector) {
            assertEq(errorArgs.length, 0, "Expected ZeroAddressValidator to have no args");
            assertTrue(
                validators.contains(address(0)),
                "expected validators to contain address(0)"
            );
        } else if (errorSelector == IQuorumFactoryErrors.EmptyQuorum.selector) {
            assertEq(errorArgs.length, 0, "Expected EmptyQuorum to have no arguments");
            assertEq(validators.length, 0, "expected validators to be empty");
        } else if (errorSelector == IConsensusFactoryErrors.ZeroEpochLength.selector) {
            assertEq(errorArgs.length, 0, "expected ZeroEpochLength to have no args");
            assertEq(epochLength, 0, "expected epoch length to be zero");
        } else {
            revert("Unexpected error");
        }
    }

    function _newQuorum(
        address[] memory validators,
        uint256 epochLength,
        uint256 claimStagingPeriod,
        bool nonDeterministicDeployment
    ) internal returns (IQuorum) {
        if (nonDeterministicDeployment) {
            vm.assumeNoRevert();
            return _factory.newQuorum(validators, epochLength, claimStagingPeriod);
        } else {
            bytes32 salt = _randomBytes32();
            vm.assumeNoRevert();
            return _factory.newQuorum(validators, epochLength, claimStagingPeriod, salt);
        }
    }

    function _encodeCallerIsNotValidator(address caller)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(IQuorum.CallerIsNotValidator.selector, caller);
    }
}
