// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {Vm} from "forge-std-1.10.0/src/Vm.sol";

import {ITournament} from "prt-contracts/ITournament.sol";
import {Machine} from "prt-contracts/types/Machine.sol";
import {Tournament} from "prt-contracts/tournament/abstracts/Tournament.sol";
import {Tree} from "prt-contracts/types/Tree.sol";

import {DaveApp} from "src/app/interfaces/DaveApp.sol";
import {DaveAppFactory} from "src/app/interfaces/DaveAppFactory.sol";

import {AppTest} from "test/util/AppTest.sol";
import {LibCannon} from "test/util/LibCannon.sol";

contract DaveAppFactoryImplTest is AppTest {
    using LibCannon for Vm;
    using Tree for Tree.Node;

    DaveAppFactory _daveAppFactory;
    DaveApp _daveApp;

    bytes32 constant GENESIS_STATE_ROOT = keccak256("genesis");
    bytes32 constant SALT = keccak256("salt");

    function setUp() external {
        _daveAppFactory = DaveAppFactory(vm.getAddress("DaveAppFactoryImpl"));
        _daveApp = _deployOrRecoverApp(GENESIS_STATE_ROOT, SALT);
        _app = _daveApp; // We downcast the Dave app for the generic app tests
        _epochFinalizerInterfaceId = type(ITournament).interfaceId;
    }

    // ----------------
    // Deployment tests
    // ----------------

    /// @notice Test the deployment of an application that uses the Dave fraud-proof system.
    /// @param blockNumber The block number in which the application is to be deployed
    /// @param genesisStateRoots Two genesis state roots used to test weak bijectivity
    /// @param salts Two salts used to test weak bijectivity
    function testDeployApp(
        uint256 blockNumber,
        bytes32[2] calldata genesisStateRoots,
        bytes32[2] calldata salts
    ) external {
        // Ensure the salts and the genesis state roots are different from each other.
        vm.assume(salts[0] != salts[1]);
        vm.assume(genesisStateRoots[0] != genesisStateRoots[1]);

        // Change the current block number so that the `getDeploymentBlockNumber`
        // view function on the `App` interface can be tested more rigorously.
        vm.roll(bound(blockNumber, vm.getBlockNumber(), type(uint256).max));

        // Deploy an app with the first genesis state root and salt.
        DaveApp app1 = _deployOrRecoverApp(genesisStateRoots[0], salts[0]);

        // Deploying an app with the same args should fail.
        // The EVM error is low-level, raised by the `CREATE2` opcode.
        vm.expectRevert(new bytes(0));
        _daveAppFactory.deployDaveApp(genesisStateRoots[0], salts[0]);

        // Deploy an app with the first genesis state root and the second salt.
        // This should yield a different app address, and, therefore, not fail.
        DaveApp app2 = _deployOrRecoverApp(genesisStateRoots[0], salts[1]);

        assertNotEq(
            address(app1),
            address(app2),
            "different salts should yield different app contracts"
        );

        // Deploy an app with the second genesis state root and the first salt.
        // This should yield a different app address, and, therefore, not fail.
        DaveApp app3 = _deployOrRecoverApp(genesisStateRoots[1], salts[0]);

        assertNotEq(
            address(app1),
            address(app3),
            "different genesis states should yield different app contracts"
        );
    }

    // -------------------
    // Data provider tests
    // -------------------

    function testProvideMerkleRootOfInput(
        bytes[][2] calldata payloads,
        bytes calldata extra
    ) external {
        // First, we add some inputs just to test that the `provideMerkleRootOfInput`
        // accepts input indices relative to the current epoch. We also store their
        // Merkle roots for later checking.
        bytes32[] memory inputMerkleRoots0 = new bytes32[](payloads[0].length);
        for (uint256 i; i < inputMerkleRoots0.length; ++i) {
            inputMerkleRoots0[i] = _app.addInput(payloads[0][i]);
        }

        // If we add at least one input, we close and finalize the epoch.
        // We cannot do that when `preInputCount = 0` because empty epochs cannot be closed.
        if (inputMerkleRoots0.length > 0) {
            _mineBlock();
            _makeOutputsValid();
        }

        // Now, we add the inputs we received as fuzzy arguments
        // and store their Merkle roots to compare with the values
        // returned by `provideMerkleRootOfInput`.
        bytes32[] memory inputMerkleRoots1 = new bytes32[](payloads[1].length);
        for (uint256 i; i < inputMerkleRoots1.length; ++i) {
            inputMerkleRoots1[i] = _app.addInput(payloads[1][i]);
        }

        // Before we close the epoch, `provideMerkleRootOfInput`
        // will return the Merkle roots of the previous (now finalized) epoch.
        for (uint256 i; i < inputMerkleRoots0.length; ++i) {
            assertEq(_daveApp.provideMerkleRootOfInput(i, extra), inputMerkleRoots0[i]);
        }

        // If we added at least one input, we can close the current epoch.
        // And then, we can query the Merkle roots from those inputs.
        if (inputMerkleRoots1.length > 0) {
            _mineBlock();
            _app.closeEpoch(_app.getFinalizedEpochCount());
            for (uint256 i; i < inputMerkleRoots1.length; ++i) {
                assertEq(
                    _daveApp.provideMerkleRootOfInput(i, extra), inputMerkleRoots1[i]
                );
            }
        }

        // For input indices beyond the current epoch boundaries,
        // the `provideMerkleRootOfInput` function returns zero.
        {
            uint256 i = vm.randomUint(inputMerkleRoots1.length, type(uint256).max);
            assertEq(_daveApp.provideMerkleRootOfInput(i, extra), bytes32(0));
        }
    }

    // -----------------
    // Virtual functions
    // -----------------

    function _preFinalizeEpoch(
        uint256,
        address epochFinalizer,
        bytes32 postEpochStateRoot
    ) internal override {
        Tournament tournament = Tournament(epochFinalizer);
        (,,, uint64 height) = tournament.tournamentLevelConstants();
        Machine.Hash finalState = Machine.Hash.wrap(postEpochStateRoot);
        bytes32[] memory proof = _randomProof(height);
        Tree.Node leftNode = _leftNodeFromProof(proof);
        Tree.Node rightNode = _rightNodeFromProof(finalState, proof);
        tournament.joinTournament(finalState, proof, leftNode, rightNode);
        while (!tournament.isClosed()) _mineBlock();
    }

    // ------------------
    // Internal functions
    // ------------------

    /// @notice Deploy an application with the provided arguments
    /// or recover it if it has been deployed already. Thanks to the
    /// deterministic nature of `CREATE2`, we can gurantee that a
    /// recovered app was also instantiated with the same arguments.
    /// @param genesisStateRoot The genesis state root
    /// @param salt The salt used to calculate the app address
    /// @return A newly-deployed app or a recovered one
    function _deployOrRecoverApp(bytes32 genesisStateRoot, bytes32 salt)
        internal
        returns (DaveApp)
    {
        address appAddress = _daveAppFactory.computeDaveAppAddress(genesisStateRoot, salt);
        if (appAddress.code.length == 0) {
            vm.expectEmit(true, false, false, false, address(_daveAppFactory));
            emit DaveAppFactory.DaveAppDeployed(DaveApp(appAddress));
            DaveApp app = _daveAppFactory.deployDaveApp(genesisStateRoot, salt);
            assertEq(address(app), appAddress);
            assertGt(appAddress.code.length, 0);
            assertEq(app.getGenesisStateRoot(), genesisStateRoot);
            assertEq(app.getDeploymentBlockNumber(), vm.getBlockNumber());
            return app;
        } else {
            return DaveApp(appAddress); // recover already-deployed app
        }
    }

    /// @notice Compute the left node of a top-level commitment from
    /// a proof of the final state (that is provided to `joinTournament`).
    /// @param proof The proof of the final machine state hash in the commitment
    /// @return leftNode The left node of the top-level commitment
    function _leftNodeFromProof(bytes32[] memory proof)
        internal
        pure
        returns (Tree.Node leftNode)
    {
        leftNode = Tree.Node.wrap(proof[proof.length - 1]);
    }

    /// @notice Compute the right node of a top-level commitment from
    /// the final machine state hash and a proof of it (provided to `joinTournament`).
    /// @param finalState The final machine state hash
    /// @param proof The proof of the final machine state hash in the commitment
    /// @return rightNode The right node of the top-level commitment
    function _rightNodeFromProof(Machine.Hash finalState, bytes32[] memory proof)
        internal
        pure
        returns (Tree.Node rightNode)
    {
        rightNode = Tree.Node.wrap(Machine.Hash.unwrap(finalState));
        for (uint256 i; i < proof.length - 1; ++i) {
            rightNode = Tree.Node.wrap(proof[i]).join(rightNode);
        }
    }
}
