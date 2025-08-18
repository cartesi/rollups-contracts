// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {Vm} from "forge-std-1.9.6/src/Vm.sol";

import {ITournament} from "prt-contracts/ITournament.sol";
import {Machine} from "prt-contracts/types/Machine.sol";
import {Tournament} from "prt-contracts/tournament/abstracts/Tournament.sol";
import {Tree} from "prt-contracts/types/Tree.sol";

import {App} from "src/app/interfaces/App.sol";
import {DaveAppFactory} from "src/app/interfaces/DaveAppFactory.sol";

import {AppTest} from "test/util/AppTest.sol";
import {LibCannon} from "test/util/LibCannon.sol";

contract DaveAppFactoryImplTest is AppTest {
    using LibCannon for Vm;
    using Tree for Tree.Node;

    DaveAppFactory _daveAppFactory;

    function setUp() external {
        _daveAppFactory = DaveAppFactory(vm.getAddress("DaveAppFactoryImpl"));
        _app = _deployOrRecoverApp(keccak256("genesis"), keccak256("salt"));
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
        App app1 = _deployOrRecoverApp(genesisStateRoots[0], salts[0]);

        // Deploying an app with the same args should fail.
        // The EVM error is low-level, raised by the `CREATE2` opcode.
        vm.expectRevert(new bytes(0));
        _daveAppFactory.deployApp(genesisStateRoots[0], salts[0]);

        // Deploy an app with the first genesis state root and the second salt.
        // This should yield a different app address, and, therefore, not fail.
        App app2 = _deployOrRecoverApp(genesisStateRoots[0], salts[1]);

        assertNotEq(
            address(app1),
            address(app2),
            "different salts should yield different app contracts"
        );

        // Deploy an app with the second genesis state root and the first salt.
        // This should yield a different app address, and, therefore, not fail.
        App app3 = _deployOrRecoverApp(genesisStateRoots[1], salts[0]);

        assertNotEq(
            address(app1),
            address(app3),
            "different genesis states should yield different app contracts"
        );
    }

    // -----------------
    // Virtual functions
    // -----------------

    /// @notice Make a post-epoch state valid.
    /// @param epochFinalizer The epoch finalizer (in this case, the tournament contract)
    /// @param postEpochStateRoot The post-epoch state root that `AppTest` wants to be valid
    /// @dev This virtual function is used by `AppTest` to test the epoch manager.
    function _makePostEpochStateValid(
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
        returns (App)
    {
        address appAddress = _daveAppFactory.computeAppAddress(genesisStateRoot, salt);
        if (appAddress.code.length == 0) {
            App app = _daveAppFactory.deployApp(genesisStateRoot, salt);
            assertEq(address(app), appAddress);
            assertGt(appAddress.code.length, 0);
            assertEq(app.getGenesisStateRoot(), genesisStateRoot);
            assertEq(app.getDeploymentBlockNumber(), vm.getBlockNumber());
            return app;
        } else {
            return App(appAddress); // recover already-deployed app
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
