// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {Test} from "forge-std-1.10.0/src/Test.sol";
import {Vm} from "forge-std-1.10.0/src/Vm.sol";

import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";

import {App} from "src/app/interfaces/App.sol";
import {CanonicalMachine} from "src/common/CanonicalMachine.sol";
import {EpochManager} from "src/app/interfaces/EpochManager.sol";
import {IERC20Portal} from "src/portals/IERC20Portal.sol";
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

    /// @notice An externally-owned account
    address immutable EOA;

    /// @notice A token contract address (to be mocked)
    address immutable TOKEN_MOCK;

    /// @notice The Ether portal
    IEtherPortal immutable ETHER_PORTAL;

    /// @notice The ERC-20 portal
    IERC20Portal immutable ERC20_PORTAL;

    /// @notice The application contract used in the tests.
    /// @dev Inheriting contracts should initialize this variable on setup.
    App _app;

    /// @notice The epoch finalizer interface ID used in the tests.
    /// @dev Inheriting contracts should initialize this variable on setup.
    bytes4 _epochFinalizerInterfaceId;

    // -----------
    // Constructor
    // -----------

    constructor() {
        EOA = _eoaFromString("EOA");
        TOKEN_MOCK = _eoaFromString("TokenMock");
        ETHER_PORTAL = IEtherPortal(vm.getAddress("EtherPortal"));
        ERC20_PORTAL = IERC20Portal(vm.getAddress("ERC20Portal"));
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

    // ------------------
    // Ether Portal tests
    // ------------------

    function testEtherDepositToEoaReverts(
        address sender,
        uint256 value,
        bytes calldata data
    ) external {
        // First, we bound the value by the current contract balance.
        value = bound(value, 0, address(this).balance);

        // Then, we deal the value to the sender.
        vm.deal(sender, value);

        // And then, we impersonate the sender.
        vm.prank(sender);

        // Depositing Ether in an EOA's account reverts
        // because the call to `addInput` returns nothing,
        // when a `bytes32` value was expected.
        vm.expectRevert();
        ETHER_PORTAL.depositEther{value: value}(App(EOA), data);
    }

    function testEtherDepositToAppSucceeds(
        address sender,
        uint256 value,
        bytes calldata data
    ) external {
        // We need to assume the sender is not the application contract
        // so that our accounting of tokens before and after makes sense.
        // It is also a fair assumption given that an application transfer
        // tokens to itself is a no-op.
        vm.assume(sender != address(_app));

        // First, we bound the value by the current contract balance.
        value = bound(value, 0, address(this).balance);

        // Then, we deal the value to the sender.
        vm.deal(sender, value);

        // We get the number of inputs as the expected input index
        // and also to check that the input count increases by 1.
        uint256 numOfInputsBefore = _app.getNumberOfInputs();

        // We encode the input to check against the InputAdded event to be emitted.
        bytes memory input = _encodeInput(
            numOfInputsBefore,
            address(ETHER_PORTAL),
            InputEncoding.encodeEtherDeposit(sender, value, data)
        );

        uint256 appBalanceBefore = address(_app).balance;

        // And then, we impersonate the sender.
        vm.prank(sender);

        // We make sure an InputAdded event is emitted
        vm.expectEmit(true, false, false, true, address(_app));
        emit Inbox.InputAdded(0, input);

        // Finally, we make the deposit
        ETHER_PORTAL.depositEther{value: value}(_app, data);

        uint256 appBalanceAfter = address(_app).balance;
        uint256 numOfInputsAfter = _app.getNumberOfInputs();

        // Make sure that the app balance has increased by the transfer value
        // and that only one input was added in the deposit tx
        assertEq(appBalanceAfter, appBalanceBefore + value);
        assertEq(numOfInputsAfter, numOfInputsBefore + 1);
    }

    // -------------------
    // ERC-20 Portal tests
    // -------------------

    function testErc20DepositSucceedsWhenTransferFromReturnsTrue(
        address sender,
        uint256 value,
        bytes calldata data
    ) external {
        // First, we encode the `transferFrom` call to be mocked.
        bytes memory transferFrom = _encodeErc20TransferFrom(sender, value);

        // Second, we make the token mock return `true` when
        // called with the expected arguments (`from`, `to`, and `value`).
        vm.mockCall(TOKEN_MOCK, transferFrom, abi.encode(true));

        // We cast the token mock as a ERC-20 token contract
        // to signal that it implements the interface (although partially).
        IERC20 token = IERC20(TOKEN_MOCK);

        // We get the number of inputs as the expected input index
        // and also to check that the input count increases by 1.
        uint256 numOfInputsBefore = _app.getNumberOfInputs();

        // We encode the input to check against the InputAdded event to be emitted.
        bytes memory input = _encodeInput(
            numOfInputsBefore,
            address(ERC20_PORTAL),
            InputEncoding.encodeERC20Deposit(token, sender, value, data)
        );

        // And then, we impersonate the sender.
        vm.prank(sender);

        // We make sure an InputAdded event is emitted.
        vm.expectEmit(true, false, false, true, address(_app));
        emit Inbox.InputAdded(numOfInputsBefore, input);

        // Finally, we make the deposit.
        ERC20_PORTAL.depositERC20Tokens(token, _app, value, data);

        uint256 numOfInputsAfter = _app.getNumberOfInputs();

        // Make sure that the app has received exactly one input.
        assertEq(numOfInputsAfter, numOfInputsBefore + 1);
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

    /// @notice Encode a `CannotCloseEmptyEpoch` error.
    /// @param epochIndex The epoch index
    /// @return The encoded error
    function _encodeCannotCloseEmptyEpoch(uint256 epochIndex)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            EpochManager.CannotCloseEmptyEpoch.selector, epochIndex
        );
    }

    /// @notice Encode an `InvalidPostEpochState` error.
    /// @param epochIndex The epoch index
    /// @param postEpochStateRoot The invalid post-epoch state root
    /// @return The encoded error
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
    /// @param length The length of the proof array
    /// @return proof An array of the given length with random `bytes32` values
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
    /// @param sibs The siblings of the node in bottom-up order
    /// @param nodeIndex The index of the node
    /// @param node The new node
    /// @param nodeFromChildren The function that computes nodes from their children
    /// @return The root hash of the new Merkle tree
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

    /// @notice Compute a post-epoch state root from a post-epoch outputs root and a proof.
    /// @param proof A Merkle proof of the post-epoch outputs root
    /// @param postEpochOutputsRoot The post-epoch outputs root
    /// @return The post-epoch state root
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

    /// @notice Computes the address of an EOA from a descriptive string
    /// @param str The string used as seed for the EOA's private key
    /// @return The EOA's address
    function _eoaFromString(string memory str) internal pure returns (address) {
        return vm.addr(boundPrivateKey(uint256(keccak256(abi.encode(str)))));
    }

    /// @notice Encode an ERC-20 `transferFrom` call from the application contract.
    /// @param sender The sender address
    /// @param value The transfer value
    /// @return The encoded Solidity function call
    function _encodeErc20TransferFrom(address sender, uint256 value)
        internal
        view
        returns (bytes memory)
    {
        return abi.encodeCall(IERC20.transferFrom, (sender, address(_app), value));
    }
}
