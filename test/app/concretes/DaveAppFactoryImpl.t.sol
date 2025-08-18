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

    function testDeployApp(
        uint256 blockNumber,
        bytes32 genesisStateRoot1,
        bytes32 genesisStateRoot2,
        bytes32 salt1,
        bytes32 salt2
    ) external {
        vm.assume(salt1 != salt2);
        vm.assume(genesisStateRoot1 != genesisStateRoot2);

        // Change the current block number so that the `getDeploymentBlockNumber`
        // view function can be tested more thoroughly.
        vm.roll(bound(blockNumber, vm.getBlockNumber(), type(uint256).max));

        App app1 = _deployOrRecoverApp(genesisStateRoot1, salt1);

        vm.expectRevert();
        _daveAppFactory.deployApp(genesisStateRoot1, salt1);

        App app2 = _deployOrRecoverApp(genesisStateRoot1, salt2);

        assertNotEq(
            address(app1),
            address(app2),
            "different salts should yield different app contracts"
        );

        App app3 = _deployOrRecoverApp(genesisStateRoot2, salt1);

        assertNotEq(
            address(app1),
            address(app3),
            "different genesis states should yield different app contracts"
        );
    }

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

    function _makePostEpochStateValid(
        uint256,
        address epochFinalizer,
        bytes32 postEpochStateRoot
    ) internal override {
        Tournament tournament = Tournament(epochFinalizer);
        (,,, uint64 height) = tournament.tournamentLevelConstants();
        Machine.Hash finalState = Machine.Hash.wrap(postEpochStateRoot);
        bytes32[] memory proof = _randomProof(height);
        Tree.Node leftNode;
        Tree.Node rightNode;
        (leftNode, rightNode) = _leftAndRightNodesFromProof(finalState, proof);
        tournament.joinTournament(finalState, proof, leftNode, rightNode);
        while (!tournament.isClosed()) _mineBlock();
    }

    function _leftAndRightNodesFromProof(Machine.Hash finalState, bytes32[] memory proof)
        internal
        pure
        returns (Tree.Node leftNode, Tree.Node rightNode)
    {
        leftNode = Tree.Node.wrap(proof[proof.length - 1]);
        rightNode = Tree.Node.wrap(Machine.Hash.unwrap(finalState));
        for (uint256 i; i < proof.length - 1; ++i) {
            rightNode = Tree.Node.wrap(proof[i]).join(rightNode);
        }
    }
}
