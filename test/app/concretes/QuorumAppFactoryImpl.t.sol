// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {Vm} from "forge-std-1.10.0/src/Vm.sol";

import {LibBitmap} from "src/library/LibBitmap.sol";
import {QuorumAppFactory} from "src/app/interfaces/QuorumAppFactory.sol";
import {QuorumApp} from "src/app/interfaces/QuorumApp.sol";
import {Quorum} from "src/app/interfaces/Quorum.sol";

import {AppTest} from "test/util/AppTest.sol";
import {LibAddressArray} from "test/util/LibAddressArray.sol";
import {LibCannon} from "test/util/LibCannon.sol";

contract QuorumAppFactoryImplTest is AppTest {
    using LibCannon for Vm;
    using LibBitmap for bytes32;
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

    // ------------
    // Quorum tests
    // ------------

    function testVoteRevertsWhenSenderIsNotValidator(
        bytes32 genesisStateRoot,
        uint8 numOfValidators,
        bytes32 salt,
        bytes32 postEpochStateRoot
    ) external {
        // We first deploy a quorum-validated application with a random non-empty validator set.
        vm.assume(numOfValidators >= 1);
        address[] memory validators = vm.randomAddresses(numOfValidators);
        QuorumApp app = _deployOrRecoverQuorumApp(genesisStateRoot, validators, salt);

        // Then we add an input, mine a block, and close the first epoch (so that we can vote).
        // The contents of the input are not relevant, so we just add an empty input.
        _addEmptyInput();
        _mineBlock();
        app.closeEpoch(0);

        // Now that validators can vote, we pick a random address that is not that of a validator.
        // We check this last condition by querying the quorum contract for its ID.
        // If zero, we know that this address is not in the validator set.
        address notValidator = vm.randomAddress();
        vm.assume(app.getValidatorIdByAddress(notValidator) == 0);

        // We then prank this non-validator and make them attempt to vote for some random post-epoch state.
        vm.expectRevert(_encodeMessageSenderIsNotValidator(notValidator));
        vm.prank(notValidator);
        app.vote(0, postEpochStateRoot);
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
                // vote on the post-epoch state agreed upon by the majority
                _vote(quorum, validator, epochIndex, postEpochStateRoot);
            } else if (role == DISAGREER) {
                // vote on a random post-epoch state
                _vote(quorum, validator, epochIndex, bytes32(vm.randomUint()));
            } else {
                // do nothing :-)
                vm.assertEq(role, NON_VOTER);
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

    /// @notice Make quorum validator vote on post-epoch state root.
    /// @param quorum The quorum contract
    /// @param validator The validator address
    /// @param epochIndex The epoch index
    /// @param postEpochStateRoot The post-epoch state root
    /// @dev This function also checks the votes before and after.
    function _vote(
        Quorum quorum,
        address validator,
        uint256 epochIndex,
        bytes32 postEpochStateRoot
    ) internal {
        uint8 numOfValidators = quorum.getNumberOfValidators();
        uint8 validatorId = quorum.getValidatorIdByAddress(validator);
        assertGe(validatorId, 1, "not validator");
        assertLe(validatorId, numOfValidators, "invalid validator ID");

        bytes32 voteBitmapBefore = quorum.getVoteBitmap(epochIndex, postEpochStateRoot);
        uint256 votesBefore = voteBitmapBefore.countSetBits();
        bytes32 aggrVoteBitmapBefore = quorum.getAggregatedVoteBitmap(epochIndex);
        uint256 aggrVotesBefore = aggrVoteBitmapBefore.countSetBits();

        assertFalse(voteBitmapBefore.getBitAt(validatorId));
        assertFalse(aggrVoteBitmapBefore.getBitAt(validatorId));
        assertLe(votesBefore, aggrVotesBefore);
        assertLe(aggrVotesBefore, numOfValidators);

        vm.startPrank(validator);
        vm.expectEmit(true, true, true, false, address(quorum));
        emit Quorum.Vote(epochIndex, postEpochStateRoot, validator);
        quorum.vote(epochIndex, postEpochStateRoot);
        vm.stopPrank();

        bytes32 voteBitmapAfter = quorum.getVoteBitmap(epochIndex, postEpochStateRoot);
        uint256 votesAfter = voteBitmapAfter.countSetBits();
        bytes32 aggrVoteBitmapAfter = quorum.getAggregatedVoteBitmap(epochIndex);
        uint256 aggrVotesAfter = aggrVoteBitmapAfter.countSetBits();

        assertTrue(voteBitmapAfter.getBitAt(validatorId));
        assertTrue(aggrVoteBitmapAfter.getBitAt(validatorId));
        assertEq(voteBitmapAfter, voteBitmapBefore.setBitAt(validatorId));
        assertEq(aggrVoteBitmapAfter, aggrVoteBitmapBefore.setBitAt(validatorId));
        assertLe(votesAfter, aggrVotesAfter);
        assertLe(aggrVotesAfter, numOfValidators);

        assertEq(votesAfter, votesBefore + 1);
        assertEq(aggrVotesAfter, aggrVotesBefore + 1);
    }

    /// @notice Encode a `MessageSenderIsNotValidator` error.
    /// @param sender The message sender
    /// @return The encoded Solidity error
    function _encodeMessageSenderIsNotValidator(address sender)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(Quorum.MessageSenderIsNotValidator.selector, sender);
    }
}
