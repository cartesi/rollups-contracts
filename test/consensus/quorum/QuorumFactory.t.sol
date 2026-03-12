// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {IConsensus} from "src/consensus/IConsensus.sol";
import {IQuorum} from "src/consensus/quorum/IQuorum.sol";
import {IQuorumFactory} from "src/consensus/quorum/IQuorumFactory.sol";
import {QuorumFactory} from "src/consensus/quorum/QuorumFactory.sol";

import {Claim} from "../../util/Claim.sol";
import {ConsensusTestUtils} from "../../util/ConsensusTestUtils.sol";
import {ERC165Test} from "../../util/ERC165Test.sol";
import {LibAddressArray} from "../../util/LibAddressArray.sol";
import {LibBytes} from "../../util/LibBytes.sol";
import {LibClaim} from "../../util/LibClaim.sol";
import {LibConsensus} from "../../util/LibConsensus.sol";
import {LibTopic} from "../../util/LibTopic.sol";
import {LibUint256Array} from "../../util/LibUint256Array.sol";

import {Test} from "forge-std-1.9.6/src/Test.sol";
import {Vm} from "forge-std-1.9.6/src/Vm.sol";

contract QuorumFactoryTest is Test, ERC165Test, ConsensusTestUtils {
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

    function testNewQuorum(
        address[] memory validators,
        uint256 epochLength,
        bytes4 interfaceId
    ) public {
        vm.recordLogs();

        try _factory.newQuorum(validators, epochLength) returns (IQuorum quorum) {
            Vm.Log[] memory logs = vm.getRecordedLogs();
            _testNewQuorumSuccess(validators, epochLength, interfaceId, quorum, logs);
        } catch Error(string memory message) {
            _testNewQuorumFailure(validators, epochLength, message);
            return;
        } catch {
            revert("Unexpected error");
        }
    }

    function testNewQuorumDeterministic(
        address[] memory validators,
        uint256 epochLength,
        bytes4 interfaceId,
        bytes32 salt
    ) public {
        address precalculatedAddress = _factory.calculateQuorumAddress(
            validators, epochLength, salt
        );

        vm.recordLogs();

        try _factory.newQuorum(validators, epochLength, salt) returns (IQuorum quorum) {
            Vm.Log[] memory logs = vm.getRecordedLogs();

            assertEq(
                precalculatedAddress,
                address(quorum),
                "calculateQuorumAddress(...) != newQuorum(...)"
            );

            _testNewQuorumSuccess(validators, epochLength, interfaceId, quorum, logs);
        } catch Error(string memory message) {
            _testNewQuorumFailure(validators, epochLength, message);
            return;
        } catch {
            revert("Unexpected error");
        }

        assertEq(
            _factory.calculateQuorumAddress(validators, epochLength, salt),
            precalculatedAddress,
            "calculateQuorumAddress(...) is not a pure function"
        );

        // Cannot deploy an application with the same salt twice
        try _factory.newQuorum(validators, epochLength, salt) {
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
        bool nonDeterministicDeployment,
        Claim memory claim
    ) external {
        IQuorum quorum = _newQuorum(validators, epochLength, nonDeterministicDeployment);

        claim.appContract = _newActiveAppMock();

        claim.lastProcessedBlockNumber = _randomEpochFinalBlockNumber(epochLength);
        vm.roll(_randomUintGt(claim.lastProcessedBlockNumber));

        claim.proof = _randomLeafProof();

        vm.expectRevert("Quorum: caller is not validator");
        vm.prank(vm.randomAddressNotIn(validators)); // non-validator address
        quorum.submitClaim(claim);
    }

    function testSubmitClaimRevertsNotEpochFinalBlock(
        address[] memory validators,
        uint256 epochLength,
        bool nonDeterministicDeployment,
        Claim memory claim
    ) external {
        uint256 lastProcessedBlockNumber = _randomNonEpochFinalBlock(epochLength);

        IQuorum quorum = _newQuorum(validators, epochLength, nonDeterministicDeployment);

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
        bool nonDeterministicDeployment,
        Claim memory claim
    ) external {
        IQuorum quorum = _newQuorum(validators, epochLength, nonDeterministicDeployment);

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
        bool nonDeterministicDeployment,
        Claim memory claim
    ) external {
        IQuorum quorum = _newQuorum(validators, epochLength, nonDeterministicDeployment);

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
        bool nonDeterministicDeployment,
        Claim memory claim,
        bytes memory error
    ) external {
        IQuorum quorum = _newQuorum(validators, epochLength, nonDeterministicDeployment);

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
        bool nonDeterministicDeployment,
        Claim memory claim,
        bytes memory data
    ) external {
        // We make isForeclosed() return ill-sized data
        vm.assume(data.length != 32);

        IQuorum quorum = _newQuorum(validators, epochLength, nonDeterministicDeployment);

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
        bool nonDeterministicDeployment,
        Claim memory claim
    ) external {
        // We make isForeclosed() return an invalid boolean (neither 0 or 1)
        uint256 returnValue = vm.randomUint(2, type(uint256).max);

        IQuorum quorum = _newQuorum(validators, epochLength, nonDeterministicDeployment);

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
        bool nonDeterministicDeployment,
        Claim memory claim
    ) external {
        IQuorum quorum = _newQuorum(validators, epochLength, nonDeterministicDeployment);

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
        bool nonDeterministicDeployment,
        Claim memory claim
    ) external {
        IQuorum quorum = _newQuorum(validators, epochLength, nonDeterministicDeployment);

        claim.appContract = _newActiveAppMock();

        claim.lastProcessedBlockNumber = _randomEpochFinalBlockNumber(epochLength);
        vm.roll(_randomUintGt(claim.lastProcessedBlockNumber));

        claim.proof = _randomProof(_randomInvalidLeafProofSize());

        vm.expectRevert(_encodeInvalidOutputsMerkleRootProofSize(claim.proof.length));
        vm.prank(vm.randomAddressIn(validators));
        quorum.submitClaim(claim);
    }

    function testSubmitClaim(
        address[] memory validators,
        uint256 epochLength,
        bool nonDeterministicDeployment
    ) external {
        IQuorum quorum = _newQuorum(validators, epochLength, nonDeterministicDeployment);

        address appContract = _newActiveAppMock();

        uint256[] memory blockNumbers = _randomEpochFinalBlockNumbers(epochLength);

        {
            (bool isEmpty, uint256 max) = blockNumbers.max();
            assertFalse(isEmpty, "unexpected empty array of epoch final block numbers");
            vm.roll(_randomUintGt(max));
        }

        bytes32 lastFinalizedMachineMerkleRoot;

        for (uint256 claimIndex; claimIndex < blockNumbers.length; ++claimIndex) {
            uint256 lastProcessedBlockNumber = blockNumbers[claimIndex];
            bool wasEpochFinalized =
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

            if (wasEpochFinalized) {
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

            uint256 numOfWinningVotes;
            uint256 numOfLosingVotes;
            bool wasClaimAccepted;

            for (uint256 i; i < ids.length; ++i) {
                uint256 id = ids[i];

                if (!wasEpochFinalized) {
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

                if (!wasEpochFinalized) {
                    assertFalse(
                        quorum.isValidatorInFavorOf(
                            appContract, lastProcessedBlockNumber, machineMerkleRoot, id
                        ),
                        "Expected validator to not be in favor of claim"
                    );
                }

                uint256 totalNumOfSubmittedClaimsBefore =
                    quorum.getNumberOfSubmittedClaims();
                uint256 totalNumOfAcceptedClaimsBefore =
                    quorum.getNumberOfAcceptedClaims();

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
                            wasEpochFinalized,
                            "NotFirstClaim should only be raised if epoch was already finalized"
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
                uint256 numOfClaimAcceptedEvents;

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
                        } else if (topic0 == IConsensus.ClaimAccepted.selector) {
                            (uint256 arg0, bytes32 arg1, bytes32 arg2) =
                                abi.decode(log.data, (uint256, bytes32, bytes32));
                            assertEq(log.topics[1], appContract.asTopic());
                            assertEq(arg0, lastProcessedBlockNumber);
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

                if (wasEpochFinalized) {
                    assertEq(
                        numOfClaimAcceptedEvents,
                        0,
                        "expected no ClaimAccepted events if epoch was already finalized"
                    );
                } else {
                    assertEq(
                        quorum.isOutputsMerkleRootValid(winningClaim),
                        numOfWinningVotes >= majority,
                        "Once a claim is accepted, the outputs Merkle root is valid"
                    );
                    if (numOfWinningVotes == majority && !wasClaimAccepted) {
                        assertEq(
                            numOfClaimAcceptedEvents, 1, "expected 1 ClaimAccepted event"
                        );
                        assertFalse(
                            wasEpochFinalized,
                            "expected ClaimAccepted if epoch was not finalized yet"
                        );

                        wasClaimAccepted = true;

                        (bool isEmpty, uint256 max) = blockNumbers.maxBefore(claimIndex);

                        // If the claim was successful submitted, then its last processed
                        // block number cannot be equal to any past successful claim.
                        if (isEmpty || claim.lastProcessedBlockNumber > max) {
                            lastFinalizedMachineMerkleRoot = machineMerkleRoot;
                        }
                    } else {
                        assertEq(
                            numOfClaimAcceptedEvents, 0, "expected 0 ClaimAccepted events"
                        );
                    }
                }

                assertEq(
                    quorum.getLastFinalizedMachineMerkleRoot(claim.appContract),
                    lastFinalizedMachineMerkleRoot,
                    "Check last finalized machine Merkle root"
                );

                assertEq(
                    quorum.getNumberOfSubmittedClaims(),
                    totalNumOfSubmittedClaimsBefore + numOfClaimSubmittedEvents,
                    "Total number of submitted claims should be increased by number of events"
                );

                assertEq(
                    quorum.getNumberOfAcceptedClaims(),
                    totalNumOfAcceptedClaimsBefore + numOfClaimAcceptedEvents,
                    "Total number of accepted claims should be increased by number of events"
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

                vm.recordLogs();

                vm.prank(validator);
                quorum.submitClaim(claim);

                assertEq(
                    vm.getRecordedLogs().length,
                    0,
                    "submitClaim() expected to emit 0 events on subsequent call"
                );

                if (!wasEpochFinalized) {
                    assertEq(
                        quorum.isOutputsMerkleRootValid(winningClaim),
                        numOfWinningVotes >= majority,
                        "Once a claim is accepted, the outputs Merkle root is valid"
                    );
                }

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

            if (!wasEpochFinalized) {
                assertEq(
                    numOfWinningVotes, numOfWinners, "# winning votes == # winner voters"
                );
                assertEq(
                    numOfLosingVotes, numOfLosers, "# losing votes == # loser voters"
                );
                assertTrue(wasClaimAccepted, "expected ClaimAccepted event");
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
            }
        }
    }

    function _testNewQuorumSuccess(
        address[] memory validators,
        uint256 epochLength,
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

        uint256 numOfValidators = quorum.numOfValidators();
        assertGt(numOfValidators, 0, "numOfValidators() > 0");

        assertEq(quorum.getEpochLength(), epochLength, "getEpochLength() == epochLength");
        assertGt(epochLength, 0, "getEpochLength() > 0");

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

        // Also, initially, no `ClaimSubmitted` or `ClaimAccepted` were emitted.
        assertEq(
            quorum.getNumberOfSubmittedClaims(),
            0,
            "initially, getNumberOfSubmittedClaims() == 0"
        );
        assertEq(
            quorum.getNumberOfAcceptedClaims(),
            0,
            "initially, getNumberOfAcceptedClaims() == 0"
        );

        // Test ERC-165 interface
        _testSupportsInterface(quorum, interfaceId);
    }

    function _testNewQuorumFailure(
        address[] memory validators,
        uint256 epochLength,
        string memory message
    ) internal pure {
        bytes32 messageHash = keccak256(bytes(message));
        if (messageHash == keccak256("Quorum can't contain address(0)")) {
            assertTrue(
                validators.contains(address(0)),
                "expected validators to contain address(0)"
            );
        } else if (messageHash == keccak256("Quorum can't be empty")) {
            assertEq(validators.length, 0, "expected validators to be empty");
        } else if (messageHash == keccak256("epoch length must not be zero")) {
            assertEq(epochLength, 0, "expected epoch length to be zero");
        } else {
            revert("Unexpected error message");
        }
    }

    function _newQuorum(
        address[] memory validators,
        uint256 epochLength,
        bool nonDeterministicDeployment
    ) internal returns (IQuorum) {
        if (nonDeterministicDeployment) {
            vm.assumeNoRevert();
            return _factory.newQuorum(validators, epochLength);
        } else {
            bytes32 salt = _randomBytes32();
            vm.assumeNoRevert();
            return _factory.newQuorum(validators, epochLength, salt);
        }
    }
}
