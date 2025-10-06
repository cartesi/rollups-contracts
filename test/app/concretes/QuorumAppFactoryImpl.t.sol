// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {Vm} from "forge-std-1.10.0/src/Vm.sol";

import {EpochManager} from "src/app/interfaces/EpochManager.sol";
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
    function testDeployQuorumApp(
        uint256 blockNumber,
        bytes32[2] calldata genesisStateRoots,
        uint8[2] memory validatorCount,
        bytes32[2] calldata salts
    ) external {
        // Generate the array of validators.
        address[][2] memory validators;
        for (uint256 i; i < 2; ++i) {
            validatorCount[i] = _boundValidatorCount(validatorCount[i]);
            validators[i] = vm.randomAddresses(validatorCount[i]);
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

    function testDeployQuorumAppRevertsWhenValidatorsArrayIsEmpty(
        bytes32 genesisStateRoot,
        bytes32 salt
    ) external {
        vm.expectRevert("quorum must not be empty");
        _quorumAppFactory.deployQuorumApp(genesisStateRoot, new address[](0), salt);
    }

    // ------------
    // Quorum tests
    // ------------

    function testVoteRevertsWhenSenderIsNotValidator(
        bytes32 genesisStateRoot,
        uint8 validatorCount,
        bytes32 salt,
        bytes32 postEpochStateRoot
    ) external {
        // We first deploy a quorum-validated application with a random non-empty validator set.
        validatorCount = _boundValidatorCount(validatorCount);
        address[] memory validators = vm.randomAddresses(validatorCount);
        QuorumApp app = _deployOrRecoverQuorumApp(genesisStateRoot, validators, salt);

        // Then we add an input, mine a block, and close the first epoch (so that we can vote).
        // The contents of the input are not relevant, so we just add an empty input.
        app.addInput(new bytes(0));
        _mineBlock();
        app.closeEpoch(0);

        // Now that validators can vote, we pick a random address that is not that of a validator.
        // We check this last condition by querying the quorum contract for its ID.
        // If zero, we know that this address is not in the validator set.
        address notValidator = vm.randomAddress();
        vm.assume(app.getValidatorIdByAddress(notValidator) == 0);

        // We then prank this non-validator and make them attempt to vote for some random post-epoch state.
        // It should fail because they are not a validator.
        vm.expectRevert(_encodeMessageSenderIsNotValidator(notValidator));
        vm.prank(notValidator);
        app.vote(0, postEpochStateRoot);
    }

    function testVoteRevertsWhenVoteWasAlreadyCast(
        bytes32 genesisStateRoot,
        uint8 validatorCount,
        bytes32 salt,
        bytes32[2] calldata postEpochStateRoots
    ) external {
        // We first deploy a quorum-validated application with a random non-empty validator set.
        validatorCount = _boundValidatorCount(validatorCount);
        address[] memory validators = vm.randomAddresses(validatorCount);
        QuorumApp app = _deployOrRecoverQuorumApp(genesisStateRoot, validators, salt);

        // Then we add an input, mine a block, and close the first epoch (so that we can vote).
        // The contents of the input are not relevant, so we just add an empty input.
        app.addInput(new bytes(0));
        _mineBlock();
        app.closeEpoch(0);

        // We pick a random validator from the set.
        address validator = validators[vm.randomUint(0, validatorCount - 1)];

        // We then prank this validator and make them vote for some random post-epoch state.
        vm.prank(validator);
        app.vote(0, postEpochStateRoots[0]);

        // We then prank this validator and make them vote for some other random post-epoch state.
        // The post-epoch state roots could be the same, but a second vote attempt will still fail.
        vm.expectRevert(Quorum.VoteAlreadyCastForEpoch.selector);
        vm.prank(validator);
        app.vote(0, postEpochStateRoots[1]);
    }

    function testVoteRevertsWhenEpochIsOpen(
        bytes32 genesisStateRoot,
        uint8 validatorCount,
        bytes32 salt,
        bytes32 postEpochStateRoot
    ) external {
        // We first deploy a quorum-validated application with a random non-empty validator set.
        validatorCount = _boundValidatorCount(validatorCount);
        address[] memory validators = vm.randomAddresses(validatorCount);
        QuorumApp app = _deployOrRecoverQuorumApp(genesisStateRoot, validators, salt);

        // We pick a random validator from the set.
        address validator = validators[vm.randomUint(0, validatorCount - 1)];

        // We then prank this validator and make them attempt to vote for some random post-epoch state.
        // It should fail because the epoch is still open.
        vm.expectRevert(Quorum.CannotCastVoteForOpenEpoch.selector);
        vm.prank(validator);
        app.vote(0, postEpochStateRoot);
    }

    function testVoteRevertsWhenEpochIndexIsInvalid(
        bytes32 genesisStateRoot,
        uint8 validatorCount,
        bytes32 salt,
        bytes32 postEpochStateRoot,
        uint256 finalizedEpochCount
    ) external {
        // We first deploy a quorum-validated application with a random non-empty validator set.
        validatorCount = _boundValidatorCount(validatorCount);
        address[] memory validators = vm.randomAddresses(validatorCount);
        QuorumApp app = _deployOrRecoverQuorumApp(genesisStateRoot, validators, salt);

        // We finalize some epochs just to test epoch indices too low later.
        // The contents of the input and the post-epoch states are not relevant,
        // so we just add one empty input and make a majority vote on the same state.
        finalizedEpochCount = bound(finalizedEpochCount, 1, 5);
        for (uint256 i; i < finalizedEpochCount; ++i) {
            app.addInput(new bytes(0));
            _mineBlock();
            _makeOutputsValid(app);
        }
        vm.assertEq(app.getFinalizedEpochCount(), finalizedEpochCount);

        // Then we add an input, mine a block, and close the first epoch (so that we can vote).
        // The contents of the input are not relevant, so we just add an empty input.
        app.addInput(new bytes(0));
        _mineBlock();
        app.closeEpoch(app.getFinalizedEpochCount());

        // We pick a random validator from the set.
        address validator = validators[vm.randomUint(0, validatorCount - 1)];

        // We then prank this validator and make them attempt to vote for some random post-epoch state
        // for an epoch that has already past (because finalizedEpochCount >= 1).
        {
            uint256 epochIndex = vm.randomUint(0, finalizedEpochCount - 1);
            vm.expectRevert(_encodeNotFirstNonFinalizedEpoch(epochIndex));
            vm.prank(validator);
            app.vote(epochIndex, postEpochStateRoot);
        }

        // We then prank this validator and make them attempt to vote for some random post-epoch state
        // for an epoch in the future.
        {
            uint256 epochIndex = vm.randomUint(finalizedEpochCount + 1, type(uint256).max);
            vm.expectRevert(_encodeNotFirstNonFinalizedEpoch(epochIndex));
            vm.prank(validator);
            app.vote(epochIndex, postEpochStateRoot);
        }
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
        uint256 validatorCount = quorum.getValidatorCount();

        // Second, we randomly assign roles to each validator.
        uint256[] memory validatorRoles = _randomValidatorRoles(validatorCount);

        // Third, we make voting validators vote in a random order.
        // We know that validator IDs are their private keys (see the `setUp` function).
        // So, we can recompute their addresses from their PKs.
        uint256[] memory validatorIds = vm.shuffle(_range(1, validatorCount + 1));
        for (uint256 i; i < validatorCount; ++i) {
            uint256 validatorId = validatorIds[i];
            address validator = quorum.getValidatorAddressById(validatorId);
            assertNotEq(validator, address(0));
            assertEq(quorum.getValidatorIdByAddress(validator), validatorId);
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
        uint8 validatorCount = app.getValidatorCount();
        assertLe(1, validatorCount);
        assertLe(validatorCount, validators.length);
        uint8[] memory validatorIds = new uint8[](validators.length);
        for (uint256 i; i < validators.length; ++i) {
            validatorIds[i] = app.getValidatorIdByAddress(validators[i]);
            assertLe(1, validatorIds[i]);
            assertLe(validatorIds[i], validatorCount);
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
    /// @param validatorCount The number of validators
    /// @return A random array of validator roles
    /// @dev Guarantees that agreers make up the majority.
    function _randomValidatorRoles(uint256 validatorCount)
        internal
        returns (uint256[] memory)
    {
        uint256[] memory validatorRoles = new uint256[](validatorCount);

        // First, we pick a random number between 1 + floor(n/2) and n.
        // This will be the number of agreeing validators.
        uint256 agreerCount = vm.randomUint(1 + validatorCount / 2, validatorCount);
        vm.assertLe(agreerCount, validatorCount, "more agreers than validators");

        // Second, we pick a random number of disagreeing validators
        // so that the total number of voters (agreeing + disagreeing) is <= n.
        uint256 diagreerCount = vm.randomUint(0, validatorCount - agreerCount);
        vm.assertLe(diagreerCount, validatorCount, "more disagreers than validators");
        uint256 voterCount = agreerCount + diagreerCount;
        vm.assertLe(voterCount, validatorCount, "more voters than validators");

        // Third, we create an array of roles using these two numbers.
        for (uint256 i; i < validatorCount; ++i) {
            bool isVoter = (i < voterCount);
            bool isAgreer = (i < agreerCount);
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
        uint8 validatorCount = quorum.getValidatorCount();
        uint8 validatorId = quorum.getValidatorIdByAddress(validator);
        assertGe(validatorId, 1, "not validator");
        assertLe(validatorId, validatorCount, "invalid validator ID");

        bytes32 voteBitmapBefore = quorum.getVoteBitmap(epochIndex, postEpochStateRoot);
        uint256 votesBefore = voteBitmapBefore.countSetBits();
        bytes32 aggrVoteBitmapBefore = quorum.getAggregatedVoteBitmap(epochIndex);
        uint256 aggrVotesBefore = aggrVoteBitmapBefore.countSetBits();

        assertFalse(voteBitmapBefore.getBitAt(validatorId));
        assertFalse(aggrVoteBitmapBefore.getBitAt(validatorId));
        assertLe(votesBefore, aggrVotesBefore);
        assertLe(aggrVotesBefore, validatorCount);

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
        assertLe(aggrVotesAfter, validatorCount);

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

    /// @notice Encode a `NotFirstNonFinalizedEpoch` error.
    /// @param epochIndex The invalid epoch index
    /// @return The encoded Solidity error
    function _encodeNotFirstNonFinalizedEpoch(uint256 epochIndex)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            EpochManager.NotFirstNonFinalizedEpoch.selector, epochIndex
        );
    }

    /// @notice Bound the number of validators to a value that is not only
    /// valid (between 1 and 255) but also practical (a value that doesn't
    /// make deployment run out of gas).
    /// @param validatorCount The number of validators received as fuzzy argument.
    function _boundValidatorCount(uint8 validatorCount)
        internal
        pure
        returns (uint8 boundedValidatorCount)
    {
        return uint8(bound(validatorCount, 1, 10));
    }
}
