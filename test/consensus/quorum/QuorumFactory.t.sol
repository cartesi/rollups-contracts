// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {Vm} from "forge-std-1.9.6/src/Vm.sol";

import {IConsensus} from "src/consensus/IConsensus.sol";
import {IConsensusFactoryErrors} from "src/consensus/IConsensusFactoryErrors.sol";
import {IOutputsMerkleRootValidator} from "src/consensus/IOutputsMerkleRootValidator.sol";
import {IQuorum} from "src/consensus/quorum/IQuorum.sol";
import {IQuorumFactory} from "src/consensus/quorum/IQuorumFactory.sol";
import {IQuorumFactoryErrors} from "src/consensus/quorum/IQuorumFactoryErrors.sol";

import {ApplicationForeclosureMock} from "../../util/ApplicationForeclosureMock.sol";
import {Claim} from "../../util/Claim.sol";
import {ConsensusTestUtils} from "../../util/ConsensusTestUtils.sol";
import {Erc165Test} from "../../util/Erc165Test.sol";
import {LibAddressArray} from "../../util/LibAddressArray.sol";
import {LibBytes} from "../../util/LibBytes.sol";
import {LibConsensus} from "../../util/LibConsensus.sol";
import {LibTopic} from "../../util/LibTopic.sol";
import {LibUint256Array} from "../../util/LibUint256Array.sol";
import {RollupsTest} from "../../util/RollupsTest.sol";
import {VersionGetterTestUtils} from "../../util/VersionGetterTestUtils.sol";

struct DeploymentArgs {
    bool deterministic;
    address[] validators;
    uint256 epochLength;
    uint256 claimStagingPeriod;
    bytes32 salt;
}

library LibQuorumFactory {
    function newQuorum(IQuorumFactory factory, DeploymentArgs calldata deploymentArgs)
        external
        returns (IQuorum)
    {
        return deploymentArgs.deterministic
            ? factory.newQuorum(
                deploymentArgs.validators,
                deploymentArgs.epochLength,
                deploymentArgs.claimStagingPeriod,
                deploymentArgs.salt
            )
            : factory.newQuorum(
                deploymentArgs.validators,
                deploymentArgs.epochLength,
                deploymentArgs.claimStagingPeriod
            );
    }

    function calculateQuorumAddress(
        IQuorumFactory factory,
        DeploymentArgs calldata deploymentArgs
    ) external view returns (address) {
        return factory.calculateQuorumAddress(
            deploymentArgs.validators,
            deploymentArgs.epochLength,
            deploymentArgs.claimStagingPeriod,
            deploymentArgs.salt
        );
    }
}

struct AppEpoch {
    address appContract;
    uint256 lastProcessedBlockNumber;
}

library LibQuorum {
    function numOfValidatorsInFavorOfAnyClaimInEpoch(
        IQuorum quorum,
        AppEpoch memory appEpoch
    ) internal view returns (uint256) {
        return quorum.numOfValidatorsInFavorOfAnyClaimInEpoch(
            appEpoch.appContract, appEpoch.lastProcessedBlockNumber
        );
    }

    function isValidatorInFavorOfAnyClaimInEpoch(
        IQuorum quorum,
        AppEpoch memory appEpoch,
        uint256 id
    ) internal view returns (bool) {
        return quorum.isValidatorInFavorOfAnyClaimInEpoch(
            appEpoch.appContract, appEpoch.lastProcessedBlockNumber, id
        );
    }

    function numOfValidatorsInFavorOf(IQuorum quorum, Claim memory claim)
        internal
        view
        returns (uint256)
    {
        return quorum.numOfValidatorsInFavorOf(
            claim.appContract, claim.lastProcessedBlockNumber, claim.machineMerkleRoot
        );
    }

    function isValidatorInFavorOf(IQuorum quorum, Claim memory claim, uint256 id)
        internal
        view
        returns (bool)
    {
        return quorum.isValidatorInFavorOf(
            claim.appContract, claim.lastProcessedBlockNumber, claim.machineMerkleRoot, id
        );
    }
}

contract QuorumFactoryTest is
    RollupsTest,
    Erc165Test,
    ConsensusTestUtils,
    VersionGetterTestUtils
{
    using LibQuorumFactory for IQuorumFactory;
    using LibAddressArray for address[];
    using LibAddressArray for Vm;
    using LibUint256Array for uint256[];
    using LibUint256Array for Vm;
    using LibConsensus for IQuorum;
    using LibQuorum for IQuorum;
    using LibTopic for address;
    using LibBytes for bytes;

    uint256 constant MAX_VOTING_VALIDATORS = 16;

    IQuorumFactory _factory;

    function setUp() public {
        _factory = _contracts.core.quorumFactory;
        _supportedInterfaces.push(type(IOutputsMerkleRootValidator).interfaceId);
        _supportedInterfaces.push(type(IConsensus).interfaceId);
        _supportedInterfaces.push(type(IQuorum).interfaceId);
    }

    function testVersion() external view {
        _testVersion(_factory);
    }

    function testNewQuorum(DeploymentArgs calldata deploymentArgs) external {
        address quorumAddress = _factory.calculateQuorumAddress(deploymentArgs);

        vm.recordLogs();

        try _factory.newQuorum(deploymentArgs) returns (IQuorum quorum) {
            Vm.Log[] memory logs = vm.getRecordedLogs();

            if (deploymentArgs.deterministic) {
                assertEq(
                    quorumAddress,
                    address(quorum),
                    "calculateQuorumAddress(...) != newQuorum(...)"
                );
            }

            uint256 numOfQuorumCreated;

            for (uint256 i; i < logs.length; ++i) {
                Vm.Log memory log = logs[i];
                if (log.emitter == address(_factory)) {
                    bytes32 topic0 = log.topics[0];
                    if (topic0 == IQuorumFactory.QuorumCreated.selector) {
                        ++numOfQuorumCreated;
                        address arg1 = abi.decode(log.data, (address));
                        assertEq(arg1, address(quorum));
                    } else {
                        revert UnexpectedLog(log);
                    }
                } else {
                    revert UnexpectedLog(log);
                }
            }

            assertEq(numOfQuorumCreated, 1);

            // Test getters
            uint256 numOfValidators = quorum.numOfValidators();
            assertGe(numOfValidators, 1);
            assertLe(numOfValidators, deploymentArgs.validators.length);
            assertEq(quorum.getEpochLength(), deploymentArgs.epochLength);
            assertGt(deploymentArgs.epochLength, 0);
            assertEq(quorum.getClaimStagingPeriod(), deploymentArgs.claimStagingPeriod);

            // We first check that any validator in the validators array
            // has a unique ID and that this ID is assigned to them.
            address[] calldata validators = deploymentArgs.validators;
            address validator = validators[vm.randomUint(0, validators.length - 1)];
            assertNotEq(validator, address(0), "Validators should be != address(0)");
            assertGe(quorum.validatorId(validator), 1);
            assertLe(quorum.validatorId(validator), numOfValidators);
            assertEq(quorum.validatorById(quorum.validatorId(validator)), validator);

            // Then we check that any valid ID is assigned to a validator in the array.
            // By the pidgenhole principle, this can already be assumed if the
            // number of unique validators is less than or equal to the length
            // of the original array. Nevertheless, we test this for redundancy.
            uint256 id = vm.randomUint(1, numOfValidators);
            assertTrue(validators.contains(quorum.validatorById(id)));

            // We check that zero address and zero ID map to each other.
            assertEq(quorum.validatorId(address(0)), 0, "validatorId(0) == 0");
            assertEq(quorum.validatorById(0), address(0), "validatorById(0) == 0");

            // We check that non-validators are assigned ID zero.
            assertEq(quorum.validatorId(vm.randomAddressNotIn(validators)), 0);

            // We check that invalid IDs map to the zero address.
            assertEq(quorum.validatorById(_randomUintGt(numOfValidators)), address(0));

            // We pick random values for function arguments
            address appContract = vm.randomAddress();
            bytes32 outputsMerkleRoot = _randomBytes32();
            bytes32 machineMerkleRoot = _randomBytes32();
            uint256 inputIndex = vm.randomUint();
            uint256 blockNumber = vm.randomUint();
            uint256 lastProcessedBlockNumber = vm.randomUint();

            // We construct an AppEpoch struct from these random values
            AppEpoch memory appEpoch;
            appEpoch.appContract = appContract;
            appEpoch.lastProcessedBlockNumber = lastProcessedBlockNumber;

            // We construct a claim from these random values
            // The proof field will not be used
            Claim memory claim;
            claim.appContract = appContract;
            claim.lastProcessedBlockNumber = lastProcessedBlockNumber;
            claim.machineMerkleRoot = machineMerkleRoot;

            // We check that initially all outputs Merkle roots are invalid.
            assertFalse(quorum.isOutputsMerkleRootValid(appContract, outputsMerkleRoot));

            // We check that initially no machine Merkle root has been finalized.
            assertEq(quorum.getLastFinalizedMachineMerkleRoot(appContract), bytes32(0));

            // We check that initially no input was finalized.
            assertFalse(quorum.wasInputFinalized(appContract, inputIndex, blockNumber));

            // We check that initially no validator is in favor of any claim.
            assertEq(quorum.numOfValidatorsInFavorOfAnyClaimInEpoch(appEpoch), 0);
            assertEq(quorum.numOfValidatorsInFavorOf(claim), 0);
            assertFalse(quorum.isValidatorInFavorOfAnyClaimInEpoch(appEpoch, id));
            assertFalse(quorum.isValidatorInFavorOf(claim, id));

            // We check that initially every claim is unstaged.
            assertEq(
                uint256(quorum.getClaim(claim).status),
                uint256(IConsensus.ClaimStatus.UNSTAGED),
                "initially, getClaim(...).status == ClaimStatus.UNSTAGED"
            );

            // Also, initially, no claim-related events were emitted.
            assertEq(quorum.getNumberOfSubmittedClaims(vm.randomAddress()), 0);
            assertEq(quorum.getNumberOfStagedClaims(vm.randomAddress()), 0);
            assertEq(quorum.getNumberOfAcceptedClaims(vm.randomAddress()), 0);

            // Test ERC-165 interface
            _testSupportsInterface(quorum);

            // Test version
            _testVersion(quorum);

            if (deploymentArgs.deterministic) {
                assertEq(
                    _factory.calculateQuorumAddress(deploymentArgs),
                    quorumAddress,
                    "calculateQuorumAddress(...) is not a pure function"
                );

                // Cannot deploy an application with the same salt twice
                try _factory.newQuorum(deploymentArgs) {
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
            if (selector == IQuorumFactoryErrors.ZeroAddressValidator.selector) {
                assertEq(errorArgs.length, 0);
                assertTrue(deploymentArgs.validators.contains(address(0)));
            } else if (selector == IQuorumFactoryErrors.EmptyQuorum.selector) {
                assertEq(errorArgs.length, 0);
                assertEq(deploymentArgs.validators.length, 0);
            } else if (selector == IConsensusFactoryErrors.ZeroEpochLength.selector) {
                assertEq(errorArgs.length, 0);
                assertEq(deploymentArgs.epochLength, 0);
            } else {
                revert UnexpectedError(errorData);
            }
        }
    }

    function testSubmitClaimRevertsCallerIsNotValidator(DeploymentArgs calldata deploymentArgs)
        external
    {
        (IQuorum quorum, Claim memory claim) = _newQuorumAndClaim(deploymentArgs);

        _rollPast(claim.lastProcessedBlockNumber);

        address caller = vm.randomAddressNotIn(deploymentArgs.validators);

        vm.expectRevert(_encodeCallerIsNotValidator(caller));
        vm.prank(caller); // non-validator address
        quorum.submitClaim(claim);
    }

    function testSubmitClaimRevertsNotEpochFinalBlock(DeploymentArgs calldata deploymentArgs)
        external
    {
        (IQuorum quorum, Claim memory claim) = _newQuorumAndClaim(deploymentArgs);
        claim.lastProcessedBlockNumber =
            _randomNonEpochFinalBlock(deploymentArgs.epochLength);

        _rollPast(claim.lastProcessedBlockNumber);

        vm.expectRevert(
            _encodeNotEpochFinalBlock(
                claim.lastProcessedBlockNumber, deploymentArgs.epochLength
            )
        );
        vm.prank(vm.randomAddressIn(deploymentArgs.validators));
        quorum.submitClaim(claim);
    }

    function testSubmitClaimRevertNotPastBlock(DeploymentArgs calldata deploymentArgs)
        external
    {
        (IQuorum quorum, Claim memory claim) = _newQuorumAndClaim(deploymentArgs);

        vm.expectRevert(_encodeNotPastBlock(claim.lastProcessedBlockNumber));
        vm.prank(vm.randomAddressIn(deploymentArgs.validators));
        quorum.submitClaim(claim);
    }

    function testSubmitClaimRevertApplicationNotDeployed(DeploymentArgs calldata deploymentArgs)
        external
    {
        (IQuorum quorum, Claim memory claim) = _newQuorumAndClaim(deploymentArgs);
        claim.appContract = _randomAccountWithNoCode();

        _rollPast(claim.lastProcessedBlockNumber);

        vm.expectRevert(_encodeApplicationNotDeployed(claim.appContract));
        vm.prank(vm.randomAddressIn(deploymentArgs.validators));
        quorum.submitClaim(claim);
    }

    function testSubmitClaimRevertApplicationReverted(
        DeploymentArgs calldata deploymentArgs,
        bytes memory errorData
    ) external {
        (IQuorum quorum, Claim memory claim) = _newQuorumAndClaim(deploymentArgs);
        claim.appContract = _newAppMockIsForeclosedReverts(errorData);

        _rollPast(claim.lastProcessedBlockNumber);

        vm.expectRevert(_encodeApplicationReverted(claim.appContract, errorData));
        vm.prank(vm.randomAddressIn(deploymentArgs.validators));
        quorum.submitClaim(claim);
    }

    function testSubmitClaimRevertApplicationReturnIllSizedReturnData(
        DeploymentArgs calldata deploymentArgs,
        bytes memory data
    ) external {
        vm.assume(data.length != 32);

        (IQuorum quorum, Claim memory claim) = _newQuorumAndClaim(deploymentArgs);
        claim.appContract = _newAppMockIsForeclosedReturns(data);

        _rollPast(claim.lastProcessedBlockNumber);

        vm.expectRevert(_encodeIllformedApplicationReturnData(claim.appContract, data));
        vm.prank(vm.randomAddressIn(deploymentArgs.validators));
        quorum.submitClaim(claim);
    }

    function testSubmitClaimRevertApplicationReturnIllFormedReturnData(DeploymentArgs calldata deploymentArgs)
        external
    {
        bytes memory data = abi.encode(vm.randomUint(2, type(uint256).max));

        (IQuorum quorum, Claim memory claim) = _newQuorumAndClaim(deploymentArgs);
        claim.appContract = _newAppMockIsForeclosedReturns(data);

        _rollPast(claim.lastProcessedBlockNumber);

        vm.expectRevert(_encodeIllformedApplicationReturnData(claim.appContract, data));
        vm.prank(vm.randomAddressIn(deploymentArgs.validators));
        quorum.submitClaim(claim);
    }

    function testSubmitClaimRevertApplicationForeclosed(DeploymentArgs calldata deploymentArgs)
        external
    {
        (IQuorum quorum, Claim memory claim) = _newQuorumAndClaim(deploymentArgs);
        claim.appContract = _newForeclosedAppMock();

        _rollPast(claim.lastProcessedBlockNumber);

        vm.expectRevert(_encodeApplicationForeclosed(claim.appContract));
        vm.prank(vm.randomAddressIn(deploymentArgs.validators));
        quorum.submitClaim(claim);
    }

    function testSubmitClaimRevertInvalidSiblingsArrayLength(DeploymentArgs calldata deploymentArgs)
        external
    {
        (IQuorum quorum, Claim memory claim) = _newQuorumAndClaim(deploymentArgs);
        _invalidateSiblingsArray(_pickRandomLeafProofFrom(claim.proof));

        _rollPast(claim.lastProcessedBlockNumber);

        vm.expectRevert(_encodeInvalidSiblingsArrayLength());
        vm.prank(vm.randomAddressIn(deploymentArgs.validators));
        quorum.submitClaim(claim);
    }

    function testSubmitClaimRevertInvalidMachineMerkleProof(DeploymentArgs calldata deploymentArgs)
        external
    {
        (IQuorum quorum, Claim memory claim) = _newQuorumAndClaim(deploymentArgs);
        _alterDataBlock(_pickRandomLeafProofFrom(claim.proof));

        _rollPast(claim.lastProcessedBlockNumber);

        vm.expectRevert(_encodeInvalidMachineMerkleProof());
        vm.prank(vm.randomAddressIn(deploymentArgs.validators));
        quorum.submitClaim(claim);
    }

    function testSubmitClaimRevertInvalidPostEpochMachineIflagsYRegister(DeploymentArgs calldata deploymentArgs)
        external
    {
        IQuorum quorum = _newQuorum(deploymentArgs);
        Claim memory claim = _newClaim(deploymentArgs.epochLength, _initBadIflagsY);

        _rollPast(claim.lastProcessedBlockNumber);

        vm.expectRevert(_encodeInvalidPostEpochMachineIflagsYRegister());
        vm.prank(vm.randomAddressIn(deploymentArgs.validators));
        quorum.submitClaim(claim);
    }

    function testSubmitClaimRevertInvalidPostEpochMachineHtifTohostRegister(DeploymentArgs calldata deploymentArgs)
        external
    {
        IQuorum quorum = _newQuorum(deploymentArgs);
        Claim memory claim = _newClaim(deploymentArgs.epochLength, _initBadHtifTohost);

        _rollPast(claim.lastProcessedBlockNumber);

        vm.expectRevert(_encodeInvalidPostEpochMachineHtifTohostRegister());
        vm.prank(vm.randomAddressIn(deploymentArgs.validators));
        quorum.submitClaim(claim);
    }

    function testSubmitAndAcceptClaim(DeploymentArgs memory deploymentArgs) external {
        _restrictQuorumSize(deploymentArgs, MAX_VOTING_VALIDATORS);
        IQuorum quorum = _newQuorum(deploymentArgs);
        address appContract = address(new ApplicationForeclosureMock());
        uint256 epochLength = deploymentArgs.epochLength;
        uint256 claimStagingPeriod = deploymentArgs.claimStagingPeriod;
        address[] memory validators = deploymentArgs.validators;

        address[] memory appContractSingleton = new address[](1);
        appContractSingleton[0] = appContract;

        address notAppContract = vm.randomAddressNotIn(appContractSingleton);

        uint256[] memory blockNumbers = _randomEpochFinalBlockNumbers(epochLength);

        bytes32 lastFinalizedMachineMerkleRoot;
        uint256 firstUnprocessedBlockNumber;

        for (uint256 claimIndex; claimIndex < blockNumbers.length; ++claimIndex) {
            uint256 lastProcessedBlockNumber = blockNumbers[claimIndex];

            // Create an AppEpoch struct so that we can more easily query info
            // regarding validator claims for that specific epoch.
            AppEpoch memory appEpoch = AppEpoch({
                appContract: appContract,
                lastProcessedBlockNumber: lastProcessedBlockNumber
            });

            // Create an AppEpoch struct so that we can more easily query info
            // regarding validator claims for another app.
            AppEpoch memory notAppEpoch = AppEpoch({
                appContract: notAppContract,
                lastProcessedBlockNumber: lastProcessedBlockNumber
            });

            bool wasEpochStaged =
                blockNumbers.containsBefore(lastProcessedBlockNumber, claimIndex);

            Claim memory winningClaim = _randomClaim(appEpoch);
            Claim memory randomClaim = _randomClaim(appEpoch);
            Claim memory notAppClaim = _randomClaim(notAppEpoch);

            bytes32 winningMachineMerkleRoot = winningClaim.machineMerkleRoot;
            bytes32 winningOutputsMerkleRoot = winningClaim.proof.txBufferProof.dataBlock;

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

            uint256 numOfValidatorsInFavorOfAnyClaimInEpoch =
                quorum.numOfValidatorsInFavorOfAnyClaimInEpoch(appEpoch);

            if (wasEpochStaged) {
                assertGe(numOfValidatorsInFavorOfAnyClaimInEpoch, majority);
            } else {
                assertEq(numOfValidatorsInFavorOfAnyClaimInEpoch, 0);
                assertEq(quorum.numOfValidatorsInFavorOf(winningClaim), 0);
                assertEq(quorum.numOfValidatorsInFavorOf(randomClaim), 0);
            }

            _rollPast(lastProcessedBlockNumber);

            uint256 numOfWinningVotes;
            uint256 numOfLosingVotes;

            for (uint256 i; i < ids.length; ++i) {
                uint256 id = ids[i];

                bool notFirstClaim =
                    quorum.isValidatorInFavorOfAnyClaimInEpoch(appEpoch, id);

                if (!wasEpochStaged) {
                    assertFalse(notFirstClaim);
                    assertFalse(quorum.isValidatorInFavorOf(randomClaim, id));
                }

                Claim memory claim;
                bytes32 machineMerkleRoot;
                bytes32 outputsMerkleRoot;

                if (winnerIds.contains(id)) {
                    claim = winningClaim;
                    machineMerkleRoot = winningMachineMerkleRoot;
                    outputsMerkleRoot = winningOutputsMerkleRoot;
                    ++numOfWinningVotes;
                } else if (loserIds.contains(id)) {
                    claim = _randomCompetingClaim(winningClaim);
                    machineMerkleRoot = claim.machineMerkleRoot;
                    outputsMerkleRoot = claim.proof.txBufferProof.dataBlock;
                    ++numOfLosingVotes;
                } else {
                    require(nonVoterIds.contains(id), "expected non-voter");
                    continue; // skip voting
                }

                if (!wasEpochStaged) {
                    assertFalse(quorum.isValidatorInFavorOf(claim, id));
                }

                uint256 totalNumOfSubmittedClaimsBefore =
                    quorum.getNumberOfSubmittedClaims(appContract);
                uint256 totalNumOfStagedClaimsBefore =
                    quorum.getNumberOfStagedClaims(appContract);
                uint256 totalNumOfAcceptedClaimsBefore =
                    quorum.getNumberOfAcceptedClaims(appContract);

                uint256 numOfValidatorsInFavorOfAnyClaimInEpochBefore =
                    quorum.numOfValidatorsInFavorOfAnyClaimInEpoch(appEpoch);
                uint256 numOfValidatorsInFavorOfClaimBefore =
                    quorum.numOfValidatorsInFavorOf(claim);

                address validator = quorum.validatorById(id);
                assertTrue(validators.contains(validator), "voter is not validator");

                vm.expectRevert(
                    notFirstClaim
                        ? _encodeNotFirstClaim(claim)
                        : _encodeApplicationForeclosed(appContract)
                );
                this.simulateForeclosureAndClaimSubmission(quorum, validator, claim);

                if (notFirstClaim) {
                    vm.expectRevert(_encodeNotFirstClaim(claim));
                } else {
                    vm.recordLogs();
                }

                vm.prank(validator);
                quorum.submitClaim(claim);

                if (notFirstClaim) {
                    continue; // Proceed to next claim.
                }

                Vm.Log[] memory logs = vm.getRecordedLogs();

                uint256 numOfClaimSubmittedEvents;
                uint256 numOfClaimStagedEvents;

                for (uint256 j; j < logs.length; ++j) {
                    Vm.Log memory log = logs[j];
                    if (log.emitter == address(quorum)) {
                        require(log.topics.length >= 1, UnexpectedLog(log));
                        bytes32 topic0 = log.topics[0];
                        if (topic0 == IConsensus.ClaimSubmitted.selector) {
                            (uint256 arg0, bytes32 arg1, bytes32 arg2) =
                                abi.decode(log.data, (uint256, bytes32, bytes32));
                            assertEq(log.topics[1], validator.asTopic());
                            assertEq(log.topics[2], appContract.asTopic());
                            assertEq(arg0, lastProcessedBlockNumber);
                            assertEq(arg1, outputsMerkleRoot);
                            assertEq(arg2, machineMerkleRoot);
                            ++numOfClaimSubmittedEvents;
                        } else if (topic0 == IConsensus.ClaimStaged.selector) {
                            (uint256 arg0, bytes32 arg1, bytes32 arg2) =
                                abi.decode(log.data, (uint256, bytes32, bytes32));
                            assertEq(log.topics[1], appContract.asTopic());
                            assertEq(arg0, lastProcessedBlockNumber);
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

                IConsensus.Claim memory submittedClaim = quorum.getClaim(claim);

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
                        assertEq(numOfClaimStagedEvents, 0);
                        assertEq(
                            uint256(submittedClaim.status),
                            uint256(IConsensus.ClaimStatus.UNSTAGED),
                            "expected claim to be unstaged"
                        );
                    }
                }

                if (submittedClaim.status != IConsensus.ClaimStatus.UNSTAGED) {
                    assertEq(
                        submittedClaim.stagedOutputsMerkleRoot,
                        outputsMerkleRoot,
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

                if (firstUnprocessedBlockNumber >= 1) {
                    assertTrue(
                        quorum.wasInputFinalized(
                            claim.appContract,
                            vm.randomUint(), // inputIndex
                            vm.randomUint(0, firstUnprocessedBlockNumber - 1)
                        ),
                        "Check all inputs added before the first unprocessed block were finalized"
                    );
                }

                assertFalse(
                    quorum.wasInputFinalized(
                        claim.appContract,
                        vm.randomUint(), // inputIndex
                        vm.randomUint(firstUnprocessedBlockNumber, type(uint256).max)
                    ),
                    "Check all inputs added on the first unprocessed block or after were not finalized"
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

                assertTrue(
                    quorum.isValidatorInFavorOfAnyClaimInEpoch(appEpoch, id),
                    "Expected validator to be in favor of any claim in epoch"
                );
                assertEq(
                    quorum.numOfValidatorsInFavorOfAnyClaimInEpoch(appEpoch),
                    numOfValidatorsInFavorOfAnyClaimInEpochBefore + 1,
                    "Number of validators in favor of any claim in epoch should be incremented"
                );

                assertEq(
                    quorum.numOfValidatorsInFavorOf(claim),
                    numOfValidatorsInFavorOfClaimBefore + 1,
                    "Number of validators in favor of claim should be incremented"
                );

                assertTrue(
                    quorum.isValidatorInFavorOf(claim, id),
                    "Expected validator to be in favor of claim"
                );

                assertFalse(
                    quorum.wasInputFinalized(
                        notAppContract,
                        vm.randomUint(), // inputIndex
                        vm.randomUint() // blockNumber
                    ),
                    "Check all inputs from other apps were not finalized"
                );

                assertEq(quorum.getNumberOfSubmittedClaims(notAppContract), 0);
                assertEq(quorum.getNumberOfStagedClaims(notAppContract), 0);
                assertEq(quorum.getNumberOfAcceptedClaims(notAppContract), 0);
                assertEq(quorum.numOfValidatorsInFavorOfAnyClaimInEpoch(notAppEpoch), 0);
                assertFalse(quorum.isValidatorInFavorOfAnyClaimInEpoch(notAppEpoch, id));
                assertEq(quorum.numOfValidatorsInFavorOf(notAppClaim), 0);
                assertFalse(quorum.isValidatorInFavorOf(notAppClaim, id));

                vm.expectRevert(_encodeNotFirstClaim(claim));
                vm.prank(validator);
                quorum.submitClaim(claim);
            }

            if (!wasEpochStaged) {
                IConsensus.Claim memory stagedClaim = quorum.getClaim(winningClaim);

                assertEq(
                    uint256(stagedClaim.status),
                    uint256(IConsensus.ClaimStatus.STAGED),
                    "Expected winning claim to be staged"
                );

                assertEq(
                    stagedClaim.stagedOutputsMerkleRoot,
                    winningOutputsMerkleRoot,
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
                    quorum.acceptClaim(winningClaim);
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
                quorum.acceptClaim(winningClaim);

                Vm.Log[] memory logs = vm.getRecordedLogs();

                uint256 numOfClaimAcceptedEvents;

                for (uint256 i; i < logs.length; ++i) {
                    Vm.Log memory log = logs[i];
                    if (log.emitter == address(quorum)) {
                        require(log.topics.length >= 1, UnexpectedLog(log));
                        bytes32 topic0 = log.topics[0];
                        if (topic0 == IConsensus.ClaimAccepted.selector) {
                            (uint256 arg0, bytes32 arg1, bytes32 arg2) =
                                abi.decode(log.data, (uint256, bytes32, bytes32));
                            assertEq(log.topics[1], appContract.asTopic());
                            assertEq(arg0, lastProcessedBlockNumber);
                            assertEq(arg1, winningOutputsMerkleRoot);
                            assertEq(arg2, winningMachineMerkleRoot);
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

                IConsensus.Claim memory acceptedClaim = quorum.getClaim(winningClaim);

                assertEq(
                    uint256(acceptedClaim.status),
                    uint256(IConsensus.ClaimStatus.ACCEPTED),
                    "Expected winning claim to be accepted"
                );

                assertEq(
                    acceptedClaim.stagedOutputsMerkleRoot,
                    winningOutputsMerkleRoot,
                    "Expected winning outputs Merkle root to be accepted"
                );

                assertLe(
                    acceptedClaim.stagingBlockNumber + claimStagingPeriod,
                    vm.getBlockNumber(),
                    "Expected accepted claim staging period to have elapsed"
                );

                assertEq(numOfWinningVotes, numOfWinners);
                assertEq(numOfLosingVotes, numOfLosers);

                assertTrue(
                    quorum.isOutputsMerkleRootValid(winningClaim),
                    "The outputs Merkle root should be valid"
                );

                assertEq(
                    quorum.numOfValidatorsInFavorOfAnyClaimInEpoch(appEpoch),
                    numOfWinningVotes + numOfLosingVotes,
                    "numOfValidatorsInFavorOfAnyClaimInEpoch(...) == # votes"
                );

                assertEq(
                    quorum.numOfValidatorsInFavorOf(winningClaim),
                    numOfWinningVotes,
                    "numOfValidatorsInFavorOf(winningClaim...) = # winning votes"
                );

                vm.expectRevert(_encodeClaimNotStagedButAccepted(winningClaim));
                vm.prank(vm.randomAddress());
                quorum.acceptClaim(winningClaim);

                (bool isEmpty, uint256 max) = blockNumbers.maxBefore(claimIndex);

                // If the claim was successful accepted, then its last processed
                // block number cannot be equal to any past successful claim.
                if (isEmpty || lastProcessedBlockNumber > max) {
                    lastFinalizedMachineMerkleRoot = winningMachineMerkleRoot;
                    firstUnprocessedBlockNumber = lastProcessedBlockNumber + 1;
                }
            }
        }
    }

    function testAcceptClaimRevertApplicationNotDeployed(DeploymentArgs calldata deploymentArgs)
        external
    {
        (IQuorum quorum, Claim memory claim) = _newQuorumAndClaim(deploymentArgs);
        claim.appContract = _randomAccountWithNoCode();

        _rollPast(claim.lastProcessedBlockNumber);

        vm.expectRevert(_encodeApplicationNotDeployed(claim.appContract));
        vm.prank(vm.randomAddress());
        quorum.acceptClaim(claim);
    }

    function testAcceptClaimRevertApplicationReverted(
        DeploymentArgs calldata deploymentArgs,
        bytes memory errorData
    ) external {
        (IQuorum quorum, Claim memory claim) = _newQuorumAndClaim(deploymentArgs);
        claim.appContract = _newAppMockIsForeclosedReverts(errorData);

        _rollPast(claim.lastProcessedBlockNumber);

        vm.expectRevert(_encodeApplicationReverted(claim.appContract, errorData));
        vm.prank(vm.randomAddress());
        quorum.acceptClaim(claim);
    }

    function testAcceptClaimRevertApplicationReturnIllSizedReturnData(
        DeploymentArgs calldata deploymentArgs,
        bytes memory data
    ) external {
        vm.assume(data.length != 32);

        (IQuorum quorum, Claim memory claim) = _newQuorumAndClaim(deploymentArgs);
        claim.appContract = _newAppMockIsForeclosedReturns(data);

        _rollPast(claim.lastProcessedBlockNumber);

        vm.expectRevert(_encodeIllformedApplicationReturnData(claim.appContract, data));
        vm.prank(vm.randomAddress());
        quorum.acceptClaim(claim);
    }

    function testAcceptClaimRevertApplicationReturnIllFormedReturnData(DeploymentArgs calldata deploymentArgs)
        external
    {
        bytes memory data = abi.encode(vm.randomUint(2, type(uint256).max));

        (IQuorum quorum, Claim memory claim) = _newQuorumAndClaim(deploymentArgs);
        claim.appContract = _newAppMockIsForeclosedReturns(data);

        _rollPast(claim.lastProcessedBlockNumber);

        vm.expectRevert(_encodeIllformedApplicationReturnData(claim.appContract, data));
        vm.prank(vm.randomAddress());
        quorum.acceptClaim(claim);
    }

    function testAcceptClaimRevertApplicationForeclosed(DeploymentArgs calldata deploymentArgs)
        external
    {
        (IQuorum quorum, Claim memory claim) = _newQuorumAndClaim(deploymentArgs);
        claim.appContract = _newForeclosedAppMock();

        _rollPast(claim.lastProcessedBlockNumber);

        vm.expectRevert(_encodeApplicationForeclosed(claim.appContract));
        vm.prank(vm.randomAddress());
        quorum.acceptClaim(claim);
    }

    function testAcceptClaimRevertsNotEpochFinalBlock(DeploymentArgs calldata deploymentArgs)
        external
    {
        (IQuorum quorum, Claim memory claim) = _newQuorumAndClaim(deploymentArgs);
        claim.lastProcessedBlockNumber =
            _randomNonEpochFinalBlock(deploymentArgs.epochLength);

        _rollPast(claim.lastProcessedBlockNumber);

        vm.expectRevert(
            _encodeNotEpochFinalBlock(
                claim.lastProcessedBlockNumber, deploymentArgs.epochLength
            )
        );
        vm.prank(vm.randomAddress());
        quorum.acceptClaim(claim);
    }

    function testAcceptClaimRevertsNotPastBlock(DeploymentArgs calldata deploymentArgs)
        external
    {
        (IQuorum quorum, Claim memory claim) = _newQuorumAndClaim(deploymentArgs);

        vm.expectRevert(_encodeNotPastBlock(claim.lastProcessedBlockNumber));
        vm.prank(vm.randomAddress());
        quorum.acceptClaim(claim);
    }

    function testAcceptClaimRevertsUnstagedClaim(DeploymentArgs calldata deploymentArgs)
        external
    {
        (IQuorum quorum, Claim memory claim) = _newQuorumAndClaim(deploymentArgs);

        _rollPast(claim.lastProcessedBlockNumber);

        vm.expectRevert(_encodeClaimNotStagedButUnstaged(claim));
        vm.prank(vm.randomAddress());
        quorum.acceptClaim(claim);
    }

    function _newQuorum(DeploymentArgs memory deploymentArgs)
        internal
        returns (IQuorum quorum)
    {
        vm.assumeNoRevert();
        return _factory.newQuorum(deploymentArgs);
    }

    function _newQuorumAndClaim(DeploymentArgs calldata deploymentArgs)
        internal
        returns (IQuorum quorum, Claim memory claim)
    {
        quorum = _newQuorum(deploymentArgs);
        claim = _randomClaim(deploymentArgs.epochLength);
    }

    function _encodeCallerIsNotValidator(address caller)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(IQuorum.CallerIsNotValidator.selector, caller);
    }

    function _randomClaim(AppEpoch memory appEpoch)
        internal
        returns (Claim memory claim)
    {
        return _randomClaim(appEpoch.appContract, appEpoch.lastProcessedBlockNumber);
    }

    function _restrictQuorumSize(DeploymentArgs memory deploymentArgs, uint256 n)
        internal
        pure
    {
        if (deploymentArgs.validators.length > n) {
            deploymentArgs.validators = deploymentArgs.validators.truncate(n);
        }
    }
}
