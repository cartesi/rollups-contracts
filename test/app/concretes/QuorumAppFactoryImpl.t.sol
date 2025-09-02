// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {Vm} from "forge-std-1.10.0/src/Vm.sol";

import {QuorumApp} from "src/app/interfaces/QuorumApp.sol";
import {Quorum} from "src/app/interfaces/Quorum.sol";
import {QuorumAppFactory} from "src/app/interfaces/QuorumAppFactory.sol";

import {AppTest} from "test/util/AppTest.sol";
import {LibCannon} from "test/util/LibCannon.sol";
import {LibAddressArray} from "test/util/LibAddressArray.sol";

contract QuorumAppFactoryImplTest is AppTest {
    using LibCannon for Vm;
    using LibAddressArray for Vm;
    using LibAddressArray for address[];

    QuorumAppFactory _quorumAppFactory;
    QuorumApp _quorumApp;

    bytes32 constant GENESIS_STATE_ROOT = keccak256("genesis");
    bytes32 constant SALT = keccak256("salt");

    function setUp() external {
        _quorumAppFactory = QuorumAppFactory(vm.getAddress("QuorumAppFactoryImpl"));
        _quorumApp = _deployOrRecoverQuorumApp(GENESIS_STATE_ROOT, vm.addrs(7), SALT);
        _app = _quorumApp; // We downcast the Quorum app for the generic app tests
        _epochFinalizerInterfaceId = type(Quorum).interfaceId;
    }

    // ----------------
    // Deployment tests
    // ----------------

    /// @notice Test the deployment of an application validated by a quorum.
    /// @param blockNumber The block number in which the application is to be deployed
    /// @param genesisStateRoots Two genesis state roots used to test weak bijectivity
    /// @param salts Two salts used to test weak bijectivity
    function testDeployApp(
        uint256 blockNumber,
        bytes32[2] calldata genesisStateRoots,
        uint8[2] memory numOfValidators,
        bytes32[2] calldata salts
    ) external {
        // Generate the array of validators.
        address[][2] memory validators;
        for (uint256 i; i < 2; ++i) {
            vm.assume(numOfValidators[i] >= 1);
            validators[i] = vm.randomAddresses(numOfValidators[i]);
        }

        // Ensure the salts and constructor arguments are different from each other.
        vm.assume(salts[0] != salts[1]);
        vm.assume(genesisStateRoots[0] != genesisStateRoots[1]);
        vm.assume(validators[0].neq(validators[1]));

        // Change the current block number so that the `getDeploymentBlockNumber`
        // view function on the `App` interface can be tested more rigorously.
        vm.roll(bound(blockNumber, vm.getBlockNumber(), type(uint256).max));

        // Deploy an app with the first genesis state root, validator array, and salt.
        QuorumApp app1 =
            _deployOrRecoverQuorumApp(genesisStateRoots[0], validators[0], salts[0]);

        // Deploying an app with the same args should fail.
        // The EVM error is low-level, raised by the `CREATE2` opcode.
        vm.expectRevert(new bytes(0));
        _quorumAppFactory.deployQuorumApp(genesisStateRoots[0], validators[0], salts[0]);

        // Deploy an app with a different salt.
        // This should yield a different app address, and, therefore, not fail.
        QuorumApp app2 =
            _deployOrRecoverQuorumApp(genesisStateRoots[0], validators[0], salts[1]);

        assertNotEq(
            address(app1),
            address(app2),
            "different salts should yield different app contracts"
        );

        // Deploy an app with a different genesis state root.
        // This should yield a different app address, and, therefore, not fail.
        QuorumApp app3 =
            _deployOrRecoverQuorumApp(genesisStateRoots[1], validators[0], salts[0]);

        assertNotEq(
            address(app1),
            address(app3),
            "different genesis states should yield different app contracts"
        );

        // Deploy an app with a different validator array.
        // This should yield a different app address, and, therefore, not fail.
        QuorumApp app4 =
            _deployOrRecoverQuorumApp(genesisStateRoots[1], validators[1], salts[0]);

        assertNotEq(
            address(app1),
            address(app4),
            "different validator arrays should yield different app contracts"
        );
    }

    // -----------------
    // Virtual functions
    // -----------------

    uint256 constant AGREER = uint256(keccak256("agreer"));
    uint256 constant DISAGREER = uint256(keccak256("disagreer"));
    uint256 constant NON_VOTER = uint256(keccak256("non-voter"));

    function _preFinalizeEpoch(
        uint256 epochIndex,
        address epochFinalizer,
        bytes32 postEpochStateRoot
    ) internal override {
        Quorum quorum = Quorum(epochFinalizer);

        // First, we retrieve the total numbe of validators.
        uint256 numOfValidators = quorum.getNumberOfValidators();

        // Second, we randomly assign roles to each validator.
        uint256[] memory validatorRoles = _randomValidatorRoles(numOfValidators);

        // Third, we make voting validators vote in a random order.
        // We know that validator IDs are their private keys (see the `setUp` function).
        // So, we can recompute their addresses from their PKs.
        uint256[] memory validatorIds = vm.shuffle(_range(1, numOfValidators + 1));
        for (uint256 i; i < numOfValidators; ++i) {
            uint256 validatorId = validatorIds[i];
            address validator = vm.addr(validatorId);
            assertEq(
                quorum.getValidatorIdByAddress(validator),
                validatorId,
                "validator ID is not validator PK"
            );
            uint256 role = validatorRoles[validatorId - 1];
            if (role == AGREER) {
                bytes32 claim = postEpochStateRoot;
                vm.startPrank(validator);
                vm.expectEmit(true, true, true, false, epochFinalizer);
                emit Quorum.Vote(epochIndex, claim, validator);
                quorum.vote(epochIndex, claim);
                vm.stopPrank();
            } else if (role == DISAGREER) {
                bytes32 claim = bytes32(vm.randomUint());
                vm.startPrank(validator);
                vm.expectEmit(true, true, true, false, epochFinalizer);
                emit Quorum.Vote(epochIndex, claim, validator);
                quorum.vote(epochIndex, claim);
                vm.stopPrank();
            } else {
                vm.assertEq(role, NON_VOTER); // do nothing :-)
            }
        }
    }

    // ------------------
    // Internal functions
    // ------------------

    /// @notice Deploy an application with the provided arguments
    /// or recover it if it has been deployed already. Thanks to the
    /// deterministic nature of `CREATE2`, we can gurantee that a
    /// recovered app was also instantiated with the same arguments.
    /// @param genesisStateRoot The genesis state root
    /// @param validators The array of validators
    /// @param salt The salt used to calculate the app address
    /// @return app A newly-deployed app or a recovered one
    function _deployOrRecoverQuorumApp(
        bytes32 genesisStateRoot,
        address[] memory validators,
        bytes32 salt
    ) internal returns (QuorumApp app) {
        address appAddress = _computeQuorumAppAddress(genesisStateRoot, validators, salt);
        if (appAddress.code.length == 0) {
            vm.expectEmit(false, false, false, true, appAddress);
            emit Quorum.Init(validators);
            vm.expectEmit(true, false, false, false, address(_quorumAppFactory));
            emit QuorumAppFactory.QuorumAppDeployed(QuorumApp(appAddress));
            app = _quorumAppFactory.deployQuorumApp(genesisStateRoot, validators, salt);
            assertEq(address(app), appAddress);
            assertGt(appAddress.code.length, 0);
            assertEq(app.getDeploymentBlockNumber(), vm.getBlockNumber());
        } else {
            app = QuorumApp(appAddress); // recover already-deployed app
            assertLe(app.getDeploymentBlockNumber(), vm.getBlockNumber());
        }
        assertEq(app.getGenesisStateRoot(), genesisStateRoot);
        assertEq(app.getNumberOfValidators(), validators.length);
        for (uint256 i; i < validators.length; ++i) {
            assertEq(app.getValidatorIdByAddress(validators[i]), i + 1);
        }
    }

    /// @notice Compute the address of an application from its constructor arguments.
    /// @param genesisStateRoot The genesis state root
    /// @param validators The array of validators
    /// @param salt The salt used to calculate the app address
    /// @return The application contract address
    function _computeQuorumAppAddress(
        bytes32 genesisStateRoot,
        address[] memory validators,
        bytes32 salt
    ) internal view returns (address) {
        return
            _quorumAppFactory.computeQuorumAppAddress(genesisStateRoot, validators, salt);
    }

    /// @notice Generate a random array of validator roles.
    /// @param numOfValidators The number of validators
    /// @return A random array of validator roles
    /// @dev Guarantees that agreers make up the majority.
    function _randomValidatorRoles(uint256 numOfValidators)
        internal
        returns (uint256[] memory)
    {
        uint256[] memory validatorRoles = new uint256[](numOfValidators);

        // First, we pick a random number between ceil(n/2) and n.
        // This will be the number of agreeing validators.
        uint256 numOfAgreers = vm.randomUint((numOfValidators + 1) / 2, numOfValidators);
        vm.assertLe(numOfAgreers, numOfValidators, "more agreers than validators");

        // Second, we pick a random number of disagreeing validators
        // so that the total number of voters (agreeing + disagreeing) is <= n.
        uint256 numOfDisagreers = vm.randomUint(0, numOfValidators - numOfAgreers);
        vm.assertLe(numOfDisagreers, numOfValidators, "more disagreers than validators");
        uint256 numOfVoters = numOfAgreers + numOfDisagreers;
        vm.assertLe(numOfVoters, numOfValidators, "more voters than validators");

        // Third, we create an array of roles using these two numbers.
        for (uint256 i; i < numOfValidators; ++i) {
            bool isVoter = (i < numOfVoters);
            bool isAgreer = (i < numOfAgreers);
            validatorRoles[i] = isVoter ? (isAgreer ? AGREER : DISAGREER) : NON_VOTER;
        }

        // Finally, we shuffle the array to add some entropy to the tests.
        return vm.shuffle(validatorRoles);
    }
}
