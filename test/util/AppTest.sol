// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {Test} from "forge-std-1.10.0/src/Test.sol";
import {Vm} from "forge-std-1.10.0/src/Vm.sol";

import {App} from "src/app/interfaces/App.sol";
import {CanonicalMachine} from "src/common/CanonicalMachine.sol";
import {EpochManager} from "src/app/interfaces/EpochManager.sol";
import {IEtherPortal} from "src/portals/IEtherPortal.sol";
import {Inbox} from "src/app/interfaces/Inbox.sol";
import {InputEncoding} from "src/common/InputEncoding.sol";
import {Inputs} from "src/common/Inputs.sol";
import {LibBinaryMerkleTree} from "src/library/LibBinaryMerkleTree.sol";
import {LibKeccak256} from "src/library/LibKeccak256.sol";

import {LibCannon} from "test/util/LibCannon.sol";

/// @notice Tests an application contract.
/// @dev Should be inherited for a specific app contract implementation.
abstract contract AppTest is Test {
    using LibCannon for Vm;
    using LibBinaryMerkleTree for bytes32[];

    /// @notice The Ether portal
    IEtherPortal _etherPortal;

    /// @notice The application contract used in the tests.
    /// @dev Inheriting contracts should initialize this variable on setup.
    App _app;

    /// @notice The epoch finalizer interface ID used in the tests.
    /// @dev Inheriting contracts should initialize this variable on setup.
    bytes4 _epochFinalizerInterfaceId;

    // -----
    // Setup
    // -----

    function setUp() public virtual {
        _etherPortal = IEtherPortal(vm.getAddress("EtherPortal"));
    }

    // -----------
    // Inbox tests
    // -----------

    function testInboxInitialState() external view {
        assertEq(_app.getNumberOfInputs(), 0);
        assertEq(_app.getNumberOfInputsBeforeCurrentBlock(), 0);
    }

    /// @notice An inbox action
    /// @param isAddInput Whether the action is to add an input (or, alternatively, to "mine" a block)
    /// @param payload The payload to pass to addInput if isAddInput is `true`
    struct InboxAction {
        bool isAddInput;
        bytes payload;
    }

    function testInboxActions(InboxAction[] calldata actions) external {
        uint256 numberOfInputs;
        uint256 numberOfInputsBeforeCurrentBlock;
        uint256 maxPayloadLength = _computeMaxInputPayloadLength();
        for (uint256 i; i < actions.length; ++i) {
            InboxAction calldata action = actions[i];
            if (action.isAddInput) {
                bytes calldata payload = action.payload;
                if (payload.length <= maxPayloadLength) {
                    uint256 inputIndex = numberOfInputs;
                    _testAddInput(payload, inputIndex);
                    ++numberOfInputs;
                }
            } else {
                _mineBlock();
                numberOfInputsBeforeCurrentBlock = numberOfInputs;
            }
            assertEq(_app.getNumberOfInputs(), numberOfInputs);
            assertEq(
                _app.getNumberOfInputsBeforeCurrentBlock(),
                numberOfInputsBeforeCurrentBlock
            );
        }
    }

    function testAddLargestInput() external {
        uint256 maxPayloadLength = _computeMaxInputPayloadLength();
        bytes memory payload = new bytes(maxPayloadLength);
        _testAddInput(payload, 0);
    }

    function testInputTooLarge() external {
        uint256 maxPayloadLength = _computeMaxInputPayloadLength();
        bytes memory payload = new bytes(maxPayloadLength + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Inbox.InputTooLarge.selector,
                _encodeInput(0, address(0), payload).length,
                CanonicalMachine.INPUT_MAX_SIZE
            )
        );
        _app.addInput(payload);
    }

    // ------------
    // Portal tests
    // ------------

    function testEtherDepositToEoaReverts(
        uint256 eoaPk,
        address sender,
        uint256 value,
        bytes calldata data
    ) external {
        eoaPk = boundPrivateKey(eoaPk);
        address eoa = vm.addr(eoaPk);
        vm.assume(eoa.code.length == 0);

        value = bound(value, 0, address(this).balance);
        vm.deal(sender, value);

        // Depositing Ether in an EOA's account reverts
        // because the call to `addInput` returns nothing,
        // when a `bytes32` value was expected.
        vm.expectRevert();
        _etherPortal.depositEther{value: value}(App(eoa), data);
    }

    function testEtherDepositToAppSucceeds(
        address sender,
        uint256 value,
        bytes calldata data
    ) external {
        value = bound(value, 0, address(this).balance);
        vm.deal(sender, value);

        bytes memory payload = InputEncoding.encodeEtherDeposit(sender, value, data);
        bytes memory input = _encodeInput(0, address(_etherPortal), payload);

        uint256 appBalanceBefore = address(_app).balance;

        vm.prank(sender);
        vm.expectEmit(true, false, false, true, address(_app));
        emit Inbox.InputAdded(0, input);
        _etherPortal.depositEther{value: value}(_app, data);

        uint256 appBalanceAfter = address(_app).balance;

        assertEq(appBalanceAfter, appBalanceBefore + value);
        assertEq(_app.getNumberOfInputs(), 1);
    }

    // -------------------
    // Epoch manager tests
    // -------------------

    function testGetEpochFinalizerInterfaceId() external view {
        assertEq(_app.getEpochFinalizerInterfaceId(), _epochFinalizerInterfaceId);
    }

    function testGetFinalizedEpochCount() external view {
        assertEq(_app.getFinalizedEpochCount(), 0);
    }

    function testCloseAndFinalizeEpoch(bytes32[3] calldata postEpochOutputsRoots)
        external
    {
        for (uint256 epochIndex; epochIndex < postEpochOutputsRoots.length; ++epochIndex)
        {
            // Initially, the epoch is open and empty.

            vm.expectRevert(_encodeCannotCloseEmptyEpoch(epochIndex));
            _app.canEpochBeClosed(epochIndex);

            vm.expectRevert(_encodeCannotCloseEmptyEpoch(epochIndex));
            _app.closeEpoch(epochIndex);

            // Right after adding an input, the epoch is still empty.

            _app.addInput(new bytes(0));

            vm.expectRevert(_encodeCannotCloseEmptyEpoch(epochIndex));
            _app.canEpochBeClosed(epochIndex);

            vm.expectRevert(_encodeCannotCloseEmptyEpoch(epochIndex));
            _app.closeEpoch(epochIndex);

            // We need to "mine" a block for the input to be included in the epoch.

            _mineBlock();

            // This call should not revert, signaling that the epoch can be closed.
            _app.canEpochBeClosed(epochIndex);

            vm.recordLogs();

            _app.closeEpoch(epochIndex);

            // Retrieve the epoch finalizer from the logs.

            Vm.Log[] memory entries = vm.getRecordedLogs();

            uint256 numOfEpochsClosed;
            address epochFinalizer;

            for (uint256 i; i < entries.length; ++i) {
                Vm.Log memory entry = entries[i];

                if (
                    entry.emitter == address(_app)
                        && entry.topics[0] == EpochManager.EpochClosed.selector
                ) {
                    ++numOfEpochsClosed;

                    epochFinalizer = address(uint160(uint256(entry.topics[2])));

                    assertEq(uint256(entry.topics[1]), epochIndex);
                }
            }

            assertEq(numOfEpochsClosed, 1);
            assertGt(epochFinalizer.code.length, 0);

            // Generate the post-epoch state root

            bytes32[] memory proof;
            bytes32 postEpochStateRoot;
            bytes32 postEpochOutputsRoot;

            proof = _randomProof(CanonicalMachine.TREE_HEIGHT);
            postEpochOutputsRoot = postEpochOutputsRoots[epochIndex];
            postEpochStateRoot = _computePostEpochStateRoot(proof, postEpochOutputsRoot);

            vm.expectRevert(_encodeInvalidPostEpochState(epochIndex, postEpochStateRoot));
            _app.canEpochBeFinalized(epochIndex, postEpochOutputsRoot, proof);

            _makePostEpochStateValid(epochIndex, epochFinalizer, postEpochStateRoot);

            // This call should not revert, signaling that the epoch can be finalized.
            _app.canEpochBeFinalized(epochIndex, postEpochOutputsRoot, proof);

            _app.finalizeEpoch(epochIndex, postEpochOutputsRoot, proof);

            assertEq(_app.getFinalizedEpochCount(), 1 + epochIndex);
            assertTrue(_app.isOutputsRootFinal(postEpochOutputsRoot));
        }
    }

    // -----------------
    // Virtual functions
    // -----------------

    function _makePostEpochStateValid(
        uint256 epochIndex,
        address epochFinalizer,
        bytes32 postEpochStateRoot
    ) internal virtual;

    // ------------------
    // Internal functions
    // ------------------

    /// @notice Add an input and ensure that an `InputAdded` event is emitted
    /// with the correctly-encoded input as argument, and that `getInputMerkleRoot`
    /// returns the same value returned by `addInput`.
    function _testAddInput(bytes memory payload, uint256 inputIndex) internal {
        bytes memory input = _encodeInput(inputIndex, address(this), payload);
        vm.expectEmit(true, false, false, true, address(_app));
        emit Inbox.InputAdded(inputIndex, input);
        bytes32 inputMerkleRoot = _app.addInput(payload);
        assertEq(_app.getInputMerkleRoot(inputIndex), inputMerkleRoot);
    }

    /// @notice Compute the maximum input payload length.
    function _computeMaxInputPayloadLength() internal view returns (uint256) {
        // First, we encode an input with an empty payload.
        // The encoded input includes the payload offset and size,
        // as well as all the fixed-size EVM metadata.
        bytes memory input = _encodeInput(0, address(0), new bytes(0));

        // Then, we subtract the size of the input from the maximum input size
        // and round down to the closest power of 32 (because the payload is
        // padded into 32-byte EVM words).
        return 32 * ((CanonicalMachine.INPUT_MAX_SIZE - input.length) / 32);
    }

    /// @notice Encode an input.
    /// @param inputIndex The input index
    /// @param inputSender The input sender
    /// @param payload The input payload
    /// @return The input
    function _encodeInput(uint256 inputIndex, address inputSender, bytes memory payload)
        internal
        view
        returns (bytes memory)
    {
        return abi.encodeCall(
            Inputs.EvmAdvance,
            (
                block.chainid,
                address(_app),
                inputSender,
                vm.getBlockNumber(),
                vm.getBlockTimestamp(),
                block.prevrandao,
                inputIndex,
                payload
            )
        );
    }

    /// @notice Encode a `CannotCloseEmptyEpoch` event.
    function _encodeCannotCloseEmptyEpoch(uint256 epochIndex)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            EpochManager.CannotCloseEmptyEpoch.selector, epochIndex
        );
    }

    /// @notice Encode a `InvalidPostEpochState` event.
    function _encodeInvalidPostEpochState(uint256 epochIndex, bytes32 postEpochStateRoot)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            EpochManager.InvalidPostEpochState.selector, epochIndex, postEpochStateRoot
        );
    }

    /// @notice "Mine" a block, that is, increment the block number by 1.
    function _mineBlock() internal {
        vm.roll(vm.getBlockNumber() + 1);
    }

    /// @notice Generates a random proof with a given length.
    function _randomProof(uint256 length)
        internal
        view
        returns (bytes32[] memory proof)
    {
        proof = new bytes32[](length);
        for (uint256 i; i < proof.length; ++i) {
            proof[i] = bytes32(vm.randomUint());
        }
    }

    /// @notice Compute a Merkle root after replacement from a proof in memory.
    function _merkleRootAfterReplacement(
        bytes32[] memory sibs,
        uint256 nodeIndex,
        bytes32 node,
        function(bytes32, bytes32) pure returns (bytes32) nodeFromChildren
    ) internal pure returns (bytes32) {
        uint256 height = sibs.length;
        require((nodeIndex >> height) == 0, LibBinaryMerkleTree.InvalidNodeIndex());
        for (uint256 i; i < height; ++i) {
            bool isNodeLeftChild = ((nodeIndex >> i) & 1 == 0);
            bytes32 nodeSibling = sibs[i];
            node = isNodeLeftChild
                ? nodeFromChildren(node, nodeSibling)
                : nodeFromChildren(nodeSibling, node);
        }
        return node;
    }

    function _computePostEpochStateRoot(
        bytes32[] memory proof,
        bytes32 postEpochOutputsRoot
    ) internal pure returns (bytes32) {
        return _merkleRootAfterReplacement(
            proof,
            CanonicalMachine.OUTPUTS_ROOT_LEAF_INDEX,
            LibKeccak256.hashBytes(abi.encode(postEpochOutputsRoot)),
            LibKeccak256.hashPair
        );
    }
}
