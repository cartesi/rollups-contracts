// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.0;

import {Vm} from "forge-std-1.10.0/src/Vm.sol";
import {Test} from "forge-std-1.10.0/src/Test.sol";

import {Create2} from "@openzeppelin-contracts-5.2.0/utils/Create2.sol";

import {IInputBox} from "src/inputs/IInputBox.sol";
import {InputBox} from "src/inputs/InputBox.sol";

import {IDataProvider} from "prt-contracts/IDataProvider.sol";
import {ITournamentFactory} from "prt-contracts/ITournamentFactory.sol";
import {ITournament} from "prt-contracts/ITournament.sol";
import {Machine} from "prt-contracts/types/Machine.sol";
import {Tree} from "prt-contracts/types/Tree.sol";

import {EmulatorConstants} from "step/src/EmulatorConstants.sol";
import {Memory} from "step/src/Memory.sol";

import {DaveConsensus} from "src/consensus/dave/DaveConsensus.sol";

import {MockContract} from "../../util/MockContract.sol";

contract MockTournament is ITournament {
    Machine.Hash immutable _initialState;
    IDataProvider immutable _provider;
    bool _finished;
    Tree.Node _winnerCommitment;
    Machine.Hash _finalState;

    constructor(Machine.Hash initialState, IDataProvider provider) {
        _initialState = initialState;
        _provider = provider;
    }

    function finish(Tree.Node winnerCommitment, Machine.Hash finalState) external {
        _finished = true;
        _winnerCommitment = winnerCommitment;
        _finalState = finalState;
    }

    function getInitialState() external view returns (Machine.Hash) {
        return _initialState;
    }

    function getProvider() external view returns (IDataProvider) {
        return _provider;
    }

    function arbitrationResult()
        external
        view
        returns (bool finished, Tree.Node winnerCommitment, Machine.Hash finalState)
    {
        finished = _finished;
        winnerCommitment = _winnerCommitment;
        finalState = _finalState;
    }
}

contract MockTournamentFactory is ITournamentFactory {
    MockTournament[] _mockTournaments;
    bytes32 _salt;

    error IndexOutOfBounds();

    function instantiate(Machine.Hash initialState, IDataProvider provider)
        external
        returns (ITournament)
    {
        MockTournament mockTournament =
            new MockTournament{salt: _salt}(initialState, provider);
        _mockTournaments.push(mockTournament);
        return mockTournament;
    }

    function calculateTournamentAddress(Machine.Hash initialState, IDataProvider provider)
        external
        view
        returns (address)
    {
        return Create2.computeAddress(
            _salt,
            keccak256(
                abi.encodePacked(
                    type(MockTournament).creationCode, abi.encode(initialState, provider)
                )
            )
        );
    }

    function setSalt(bytes32 salt) external {
        _salt = salt;
    }

    function getNumberOfMockTournaments() external view returns (uint256) {
        return _mockTournaments.length;
    }

    function getMockTournament(uint256 index) external view returns (MockTournament) {
        if (index < _mockTournaments.length) {
            return _mockTournaments[index];
        } else {
            revert IndexOutOfBounds();
        }
    }
}

contract DaveConsensusTest is Test {
    IInputBox _inputBox;
    MockTournamentFactory _mockTournamentFactory;

    function setUp() external {
        _inputBox = new InputBox();
        _mockTournamentFactory = new MockTournamentFactory();
    }

    function testMockTournamentFactory() external view {
        assertEq(_mockTournamentFactory.getNumberOfMockTournaments(), 0);
    }

    function testMockTournamentFactory(uint256 index) external {
        vm.expectRevert(MockTournamentFactory.IndexOutOfBounds.selector);
        _mockTournamentFactory.getMockTournament(index);
    }

    function testConstructorAndSettle(
        bytes32[3] calldata outputsMerkleRoots,
        uint256[2] memory inputCounts,
        bytes32[3] calldata salts,
        Tree.Node[2] calldata winnerCommitments
    ) external {
        address appContract = address(new MockContract());

        for (uint256 i; i < 2; ++i) {
            inputCounts[i] = bound(inputCounts[i], 0, 5);
        }

        _addInputs(appContract, inputCounts[0]);

        (Machine.Hash state0,,) = _statesAndProofs(outputsMerkleRoots[0]);
        address daveConsensusAddress =
            _calculateNewDaveConsensus(appContract, state0, salts[0]);

        _mockTournamentFactory.setSalt(salts[1]);
        address mockTournamentAddress = _mockTournamentFactory.calculateTournamentAddress(
            state0, IDataProvider(daveConsensusAddress)
        );

        vm.expectEmit(daveConsensusAddress);
        emit DaveConsensus.ConsensusCreation(
            _inputBox, appContract, _mockTournamentFactory
        );

        vm.expectEmit(daveConsensusAddress);
        emit DaveConsensus.EpochSealed(
            0, 0, inputCounts[0], state0, bytes32(0), ITournament(mockTournamentAddress)
        );

        DaveConsensus daveConsensus = _newDaveConsensus(appContract, state0, salts[0]);

        assertEq(address(daveConsensus), daveConsensusAddress);
        assertEq(address(daveConsensus.getInputBox()), address(_inputBox));
        assertEq(daveConsensus.getApplicationContract(), appContract);
        assertEq(
            address(daveConsensus.getTournamentFactory()), address(_mockTournamentFactory)
        );

        {
            bool isFinished;
            uint256 epochNumber;

            (isFinished, epochNumber,) = daveConsensus.canSettle();

            assertFalse(isFinished);
            assertEq(epochNumber, 0);
        }

        {
            uint256 epochNumber;
            uint256 inputIndexLowerBound;
            uint256 inputIndexUpperBound;
            ITournament tournament;

            (epochNumber, inputIndexLowerBound, inputIndexUpperBound, tournament) =
                daveConsensus.getCurrentSealedEpoch();

            assertEq(epochNumber, 0);
            assertEq(inputIndexLowerBound, 0);
            assertEq(inputIndexUpperBound, inputCounts[0]);
            assertEq(address(tournament), mockTournamentAddress);
        }

        assertEq(_mockTournamentFactory.getNumberOfMockTournaments(), 1);
        assertEq(
            address(_mockTournamentFactory.getMockTournament(0)), mockTournamentAddress
        );

        MockTournament mockTournament = MockTournament(mockTournamentAddress);

        assertEq(
            Machine.Hash.unwrap(mockTournament.getInitialState()),
            Machine.Hash.unwrap(state0)
        );
        assertEq(address(mockTournament.getProvider()), address(daveConsensus));

        {
            (bool isFinished,,) = mockTournament.arbitrationResult();

            assertFalse(isFinished);
        }

        (Machine.Hash state1, bytes32[] memory proof1, bytes32 leaf1) =
            _statesAndProofs(outputsMerkleRoots[1]);
        mockTournament.finish(winnerCommitments[0], state1);

        {
            bool isFinished;
            Tree.Node winnerCommitmentTmp;
            Machine.Hash finalStateTmp;

            (isFinished, winnerCommitmentTmp, finalStateTmp) =
                mockTournament.arbitrationResult();

            assertTrue(isFinished);
            assertEq(
                Tree.Node.unwrap(winnerCommitmentTmp),
                Tree.Node.unwrap(winnerCommitments[0])
            );
            assertEq(Machine.Hash.unwrap(finalStateTmp), Machine.Hash.unwrap(state1));
        }

        {
            bool isFinished;
            uint256 epochNumber;

            (isFinished, epochNumber,) = daveConsensus.canSettle();

            assertTrue(isFinished);
            assertEq(epochNumber, 0);
        }

        _addInputs(appContract, inputCounts[1]);

        address previousMockTournamentAddress = mockTournamentAddress;

        _mockTournamentFactory.setSalt(salts[2]);
        mockTournamentAddress = _mockTournamentFactory.calculateTournamentAddress(
            state1, IDataProvider(daveConsensusAddress)
        );

        vm.expectEmit(daveConsensusAddress);
        emit DaveConsensus.EpochSealed(
            1,
            inputCounts[0],
            inputCounts[0] + inputCounts[1],
            state1,
            leaf1,
            ITournament(mockTournamentAddress)
        );

        daveConsensus.settle(0, leaf1, proof1);

        {
            bool isFinished;
            uint256 epochNumber;

            (isFinished, epochNumber,) = daveConsensus.canSettle();

            assertFalse(isFinished);
            assertEq(epochNumber, 1);
        }

        {
            uint256 epochNumber;
            uint256 inputIndexLowerBound;
            uint256 inputIndexUpperBound;
            ITournament tournament;

            (epochNumber, inputIndexLowerBound, inputIndexUpperBound, tournament) =
                daveConsensus.getCurrentSealedEpoch();

            assertEq(epochNumber, 1);
            assertEq(inputIndexLowerBound, inputCounts[0]);
            assertEq(inputIndexUpperBound, inputCounts[0] + inputCounts[1]);
            assertEq(address(tournament), mockTournamentAddress);
        }

        assertEq(_mockTournamentFactory.getNumberOfMockTournaments(), 2);
        assertEq(
            address(_mockTournamentFactory.getMockTournament(0)),
            previousMockTournamentAddress
        );
        assertEq(
            address(_mockTournamentFactory.getMockTournament(1)), mockTournamentAddress
        );

        mockTournament = MockTournament(mockTournamentAddress);

        assertEq(
            Machine.Hash.unwrap(mockTournament.getInitialState()),
            Machine.Hash.unwrap(state1)
        );
        assertEq(address(mockTournament.getProvider()), address(daveConsensus));

        {
            (bool isFinished,,) = mockTournament.arbitrationResult();

            assertFalse(isFinished);
        }

        (Machine.Hash state2,,) = _statesAndProofs(outputsMerkleRoots[2]);
        mockTournament.finish(winnerCommitments[1], state2);

        {
            bool isFinished;
            Tree.Node winnerCommitmentTmp;
            Machine.Hash finalStateTmp;

            (isFinished, winnerCommitmentTmp, finalStateTmp) =
                mockTournament.arbitrationResult();

            assertTrue(isFinished);
            assertEq(
                Tree.Node.unwrap(winnerCommitmentTmp),
                Tree.Node.unwrap(winnerCommitments[1])
            );
            assertEq(Machine.Hash.unwrap(finalStateTmp), Machine.Hash.unwrap(state2));
        }
    }

    function testSettleReverts(
        Machine.Hash[2] calldata states,
        uint256[2] memory inputCounts,
        bytes32[2] calldata salts,
        uint256 wrongEpochNumber
    ) external {
        address appContract = address(new MockContract());

        vm.assume(wrongEpochNumber != 0);

        for (uint256 i; i < 2; ++i) {
            inputCounts[i] = bound(inputCounts[i], 0, 5);
        }

        _addInputs(appContract, inputCounts[0]);

        _mockTournamentFactory.setSalt(salts[0]);

        DaveConsensus daveConsensus = _newDaveConsensus(appContract, states[0], salts[1]);

        _addInputs(appContract, inputCounts[1]);

        vm.expectRevert(
            abi.encodeWithSelector(
                DaveConsensus.IncorrectEpochNumber.selector, wrongEpochNumber, 0
            )
        );
        daveConsensus.settle(wrongEpochNumber, bytes32(0), new bytes32[](0));

        vm.expectRevert(DaveConsensus.TournamentNotFinishedYet.selector);
        daveConsensus.settle(0, bytes32(0), new bytes32[](0));
    }

    function testProvideMerkleRootOfInput(
        bytes[] calldata payloads,
        uint256 inputIndexWithinBounds,
        uint256 inputIndexOutsideBounds,
        Machine.Hash initialState,
        bytes32[2] calldata salts
    ) external {
        address appContract = address(new MockContract());

        _addInputs(appContract, payloads);

        _mockTournamentFactory.setSalt(salts[0]);

        DaveConsensus daveConsensus =
            _newDaveConsensus(appContract, initialState, salts[1]);

        if (payloads.length > 0) {
            inputIndexWithinBounds = bound(inputIndexWithinBounds, 0, payloads.length - 1);
            bytes32 root = daveConsensus.provideMerkleRootOfInput(
                inputIndexWithinBounds, new bytes(0)
            );
            assertEq(
                root, _inputBox.getInputMerkleRoot(appContract, inputIndexWithinBounds)
            );
        }

        {
            inputIndexOutsideBounds =
                bound(inputIndexOutsideBounds, payloads.length, type(uint256).max);
            bytes32 root = daveConsensus.provideMerkleRootOfInput(
                inputIndexOutsideBounds, new bytes(0)
            );
            assertEq(root, bytes32(0));
        }
    }

    function _addInputs(address appContract, uint256 n) internal {
        for (uint256 i; i < n; ++i) {
            _inputBox.addInput(appContract, new bytes(0));
        }
    }

    function _addInputs(address appContract, bytes[] calldata payloads) internal {
        for (uint256 i; i < payloads.length; ++i) {
            _inputBox.addInput(appContract, payloads[i]);
        }
    }

    function _calculateNewDaveConsensus(
        address appContract,
        Machine.Hash initialState,
        bytes32 salt
    ) internal view returns (address) {
        return Create2.computeAddress(
            salt,
            keccak256(
                abi.encodePacked(
                    type(DaveConsensus).creationCode,
                    abi.encode(
                        _inputBox, appContract, _mockTournamentFactory, initialState
                    )
                )
            )
        );
    }

    function _newDaveConsensus(
        address appContract,
        Machine.Hash initialState,
        bytes32 salt
    ) internal returns (DaveConsensus) {
        return new DaveConsensus{salt: salt}(
            _inputBox, appContract, _mockTournamentFactory, initialState
        );
    }

    function _statesAndProofs(bytes32 outputsMerkleRoot)
        internal
        pure
        returns (Machine.Hash, bytes32[] memory, bytes32)
    {
        uint256 levels = Memory.LOG2_MAX_SIZE;
        bytes32[] memory siblings = new bytes32[](levels);

        bytes32 leaf = keccak256(abi.encode(outputsMerkleRoot));
        bytes32 current = leaf;
        for (uint256 i; i < levels; ++i) {
            siblings[i] = current;
            current = keccak256(abi.encodePacked(current, current));
        }

        return (Machine.Hash.wrap(current), siblings, outputsMerkleRoot);
    }
}
