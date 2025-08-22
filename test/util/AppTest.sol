// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {Test} from "forge-std-1.10.0/src/Test.sol";
import {Vm} from "forge-std-1.10.0/src/Vm.sol";

import {IERC1155Errors} from "@openzeppelin-contracts-5.2.0/interfaces/draft-IERC6093.sol";
import {IERC1155} from "@openzeppelin-contracts-5.2.0/token/ERC1155/IERC1155.sol";
import {IERC20Errors} from "@openzeppelin-contracts-5.2.0/interfaces/draft-IERC6093.sol";
import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";
import {IERC721Errors} from "@openzeppelin-contracts-5.2.0/interfaces/draft-IERC6093.sol";
import {IERC721} from "@openzeppelin-contracts-5.2.0/token/ERC721/IERC721.sol";

import {App} from "src/app/interfaces/App.sol";
import {CanonicalMachine} from "src/common/CanonicalMachine.sol";
import {EpochManager} from "src/app/interfaces/EpochManager.sol";
import {IERC20Portal} from "src/portals/IERC20Portal.sol";
import {IERC721Portal} from "src/portals/IERC721Portal.sol";
import {IERC1155SinglePortal} from "src/portals/IERC1155SinglePortal.sol";
import {IEtherPortal} from "src/portals/IEtherPortal.sol";
import {Inbox} from "src/app/interfaces/Inbox.sol";
import {InputEncoding} from "src/common/InputEncoding.sol";
import {Inputs} from "src/common/Inputs.sol";
import {LibBinaryMerkleTree} from "src/library/LibBinaryMerkleTree.sol";
import {LibKeccak256} from "src/library/LibKeccak256.sol";

import {LibCannon} from "test/util/LibCannon.sol";
import {SimpleERC20} from "test/util/SimpleERC20.sol";
import {SimpleERC721} from "test/util/SimpleERC721.sol";
import {SimpleSingleERC1155} from "test/util/SimpleERC1155.sol";

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

    /// @notice The ERC-721 portal
    IERC721Portal immutable ERC721_PORTAL;

    /// @notice The ERC-1155 single portal
    IERC1155SinglePortal immutable ERC1155_SINGLE_PORTAL;

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
        ERC721_PORTAL = IERC721Portal(vm.getAddress("ERC721Portal"));
        ERC1155_SINGLE_PORTAL = IERC1155SinglePortal(vm.getAddress("ERC1155SinglePortal"));
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

    function testErc20DepositRevertsWhenTransferFromReturnsFalse(
        address sender,
        uint256 value,
        bytes calldata data
    ) external {
        // First, we encode the `transferFrom` call to be mocked.
        bytes memory transferFrom = _encodeErc20TransferFrom(sender, value);

        // Second, we make the token mock return `false` when
        // called with the expected arguments (`from`, `to`, and `value`).
        vm.mockCall(TOKEN_MOCK, transferFrom, abi.encode(false));

        // We cast the token mock as a ERC-20 token contract
        // to signal that it implements the interface (although partially).
        IERC20 token = IERC20(TOKEN_MOCK);

        // And then, we impersonate the sender.
        vm.prank(sender);

        // Finally, we try to make the deposit, expecting it to revert.
        vm.expectRevert(IERC20Portal.ERC20TransferFailed.selector);
        ERC20_PORTAL.depositERC20Tokens(token, _app, value, data);
    }

    function testErc20DepositRevertsWhenTransferFromReverts(
        address sender,
        uint256 value,
        bytes calldata data,
        bytes calldata errorData
    ) external {
        // First, we encode the `transferFrom` call to be mocked.
        bytes memory transferFrom = _encodeErc20TransferFrom(sender, value);

        // Second, we make the token mock revert when
        // called with the expected arguments (`from`, `to`, and `value`).
        vm.mockCallRevert(TOKEN_MOCK, transferFrom, errorData);

        // We cast the token mock as a ERC-20 token contract
        // to signal that it implements the interface (although partially).
        IERC20 token = IERC20(TOKEN_MOCK);

        // And then, we impersonate the sender.
        vm.prank(sender);

        // Finally, we try to make the deposit, expecting it to revert
        // with the same error raised by `transferFrom`.
        vm.expectRevert(errorData);
        ERC20_PORTAL.depositERC20Tokens(token, _app, value, data);
    }

    function testOpenZeppelinErc20DepositRevertsWhenSenderHasntGivenSufficientAllowance(
        address sender,
        uint256 allowance,
        uint256 value,
        uint256 balance,
        bytes calldata data
    ) external {
        // Assume sender is not the zero address.
        // Otherwise, the token contract raises `ERC20InvalidReceiver`.
        // This is a fair assumption, given that the private key of zero address is unknown.
        vm.assume(sender != address(0));

        // Bound the value, allowance, and balance.
        // We need 0 <= allowance < value <= balance <= type(uint256).max
        allowance = bound(allowance, 0, type(uint256).max - 1);
        value = bound(value, allowance + 1, type(uint256).max);
        balance = bound(balance, value, type(uint256).max);

        // Deploy an OpenZeppelin ERC-20 token contract.
        IERC20 token = _deployOpenZeppelinErc20Token(sender, balance);

        // Give allowance to the ERC-20 portal
        vm.prank(sender);
        token.approve(address(ERC20_PORTAL), allowance);

        // Finally, the sender tries to deposit the tokens.
        // We expect it to fail because the sender has given insufficient allowance to the portal.
        vm.prank(sender);
        vm.expectRevert(_encodeErc20InsufficientAllowance(allowance, value));
        ERC20_PORTAL.depositERC20Tokens(token, _app, value, data);
    }

    function testOpenZeppelinErc20DepositRevertsWhenSenderHasInsufficientBalance(
        address sender,
        uint256 allowance,
        uint256 value,
        uint256 balance,
        bytes calldata data
    ) external {
        // Assume sender is not the zero address.
        // Otherwise, the token contract raises `ERC20InvalidReceiver`.
        // This is a fair assumption, given that the private key of zero address is unknown.
        vm.assume(sender != address(0));

        // Bound the value, allowance, and balance.
        // We need 0 <= balance < value <= allowance <= type(uint256).max
        balance = bound(balance, 0, type(uint256).max - 1);
        value = bound(value, balance + 1, type(uint256).max);
        allowance = bound(allowance, value, type(uint256).max);

        // Deploy an OpenZeppelin ERC-20 token contract.
        IERC20 token = _deployOpenZeppelinErc20Token(sender, balance);

        // Give allowance to the ERC-20 portal
        vm.prank(sender);
        token.approve(address(ERC20_PORTAL), allowance);

        // Finally, the sender tries to deposit the tokens.
        // We expect it to fail because the sender has given insufficient allowance to the portal.
        vm.prank(sender);
        vm.expectRevert(_encodeErc20InsufficientBalance(sender, balance, value));
        ERC20_PORTAL.depositERC20Tokens(token, _app, value, data);
    }

    function testOpenZeppelinErc20DepositSucceeds(
        address sender,
        uint256 value,
        uint256 allowance,
        uint256 balance,
        bytes calldata data
    ) external {
        // We need to assume the sender is not the application contract
        // so that our accounting of tokens before and after makes sense.
        // It is also a fair assumption given that an application transfer
        // tokens to itself is a no-op.
        vm.assume(sender != address(_app));

        // Assume sender is not the zero address.
        // Otherwise, the token contract raises `ERC20InvalidReceiver`.
        // This is a fair assumption, given that the private key of zero address is unknown.
        vm.assume(sender != address(0));

        // Bound the value, allowance, and balance.
        // We need 0 <= value <= allowance, balance <= type(uint256).max
        allowance = bound(allowance, value, type(uint256).max);
        balance = bound(balance, value, type(uint256).max);

        // Deploy an OpenZeppelin ERC-20 token contract.
        IERC20 token = _deployOpenZeppelinErc20Token(sender, balance);

        // Give allowance to the ERC-20 portal
        vm.prank(sender);
        token.approve(address(ERC20_PORTAL), allowance);

        // We get the number of inputs as the expected input index
        // and also to check that the input count increases by 1.
        uint256 numOfInputsBefore = _app.getNumberOfInputs();

        // We encode the input to check against the InputAdded event to be emitted.
        bytes memory input = _encodeInput(
            numOfInputsBefore,
            address(ERC20_PORTAL),
            InputEncoding.encodeERC20Deposit(token, sender, value, data)
        );

        uint256 appBalanceBefore = token.balanceOf(address(_app));

        // And then, we impersonate the sender.
        vm.prank(sender);

        // We make sure an InputAdded event is emitted.
        vm.expectEmit(true, false, false, true, address(_app));
        emit Inbox.InputAdded(numOfInputsBefore, input);

        // Finally, we make the deposit.
        ERC20_PORTAL.depositERC20Tokens(token, _app, value, data);

        uint256 appBalanceAfter = token.balanceOf(address(_app));
        uint256 numOfInputsAfter = _app.getNumberOfInputs();

        // Make sure that the app balance has increased by the transfer value
        // and that only one input was added in the deposit tx
        assertEq(appBalanceAfter, appBalanceBefore + value);
        assertEq(numOfInputsAfter, numOfInputsBefore + 1);
    }

    // --------------------
    // ERC-721 Portal tests
    // --------------------

    function testErc721DepositWhenSafeTransferFromReturns(
        address sender,
        uint256 tokenId,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external {
        // First, we encode the `safeTransferFrom` call to be mocked.
        bytes memory safeTransferFrom =
            _encodeErc721SafeTransferFrom(sender, tokenId, baseLayerData);

        // Second, we make the token mock return when
        // called with the expected arguments (`from`, `to`, `tokenId`, and `data`).
        vm.mockCall(TOKEN_MOCK, safeTransferFrom, abi.encode());

        // We cast the token mock as a ERC-721 token contract
        // to signal that it implements the interface (although partially).
        IERC721 token = IERC721(TOKEN_MOCK);

        // We get the number of inputs as the expected input index
        // and also to check that the input count increases by 1.
        uint256 numOfInputsBefore = _app.getNumberOfInputs();

        // We encode the input to check against the InputAdded event to be emitted.
        bytes memory input = _encodeInput(
            numOfInputsBefore,
            address(ERC721_PORTAL),
            InputEncoding.encodeERC721Deposit(
                token, sender, tokenId, baseLayerData, execLayerData
            )
        );

        // And then, we impersonate the sender.
        vm.prank(sender);

        // We make sure an InputAdded event is emitted.
        vm.expectEmit(true, false, false, true, address(_app));
        emit Inbox.InputAdded(numOfInputsBefore, input);

        // Finally, we make the deposit.
        ERC721_PORTAL.depositERC721Token(
            token, _app, tokenId, baseLayerData, execLayerData
        );

        uint256 numOfInputsAfter = _app.getNumberOfInputs();

        // Make sure that the app has received exactly one input.
        assertEq(numOfInputsAfter, numOfInputsBefore + 1);
    }

    function testErc721DepositWhenSafeTransferFromReverts(
        address sender,
        uint256 tokenId,
        bytes calldata baseLayerData,
        bytes calldata execLayerData,
        bytes calldata errorData
    ) external {
        // First, we encode the `safeTransferFrom` call to be mocked.
        bytes memory safeTransferFrom =
            _encodeErc721SafeTransferFrom(sender, tokenId, baseLayerData);

        // Second, we make the token mock return when
        // called with the expected arguments (`from`, `to`, `tokenId`, and `data`).
        vm.mockCallRevert(TOKEN_MOCK, safeTransferFrom, errorData);

        // We cast the token mock as a ERC-721 token contract
        // to signal that it implements the interface (although partially).
        IERC721 token = IERC721(TOKEN_MOCK);

        // And then, we impersonate the sender.
        vm.prank(sender);

        // Finally, we try to make the deposit, expecting it to revert
        // with the same error raised by `safeTransferFrom`.
        vm.expectRevert(errorData);
        ERC721_PORTAL.depositERC721Token(
            token, _app, tokenId, baseLayerData, execLayerData
        );
    }

    function testOpenZeppelinErc721DepositRevertsWhenSenderHasntGivenSufficientApproval(
        address sender,
        uint256 tokenId,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external {
        // Assume sender is not the zero address.
        // Otherwise, the token contract raises `ERC721InvalidReceiver`.
        // This is a fair assumption, given that the private key of zero address is unknown.
        vm.assume(sender != address(0));

        // Assume sender is an EOA.
        // Otherwise, the token contract raises `ERC721InvalidReceiver`
        // because it probably doesn't implement the interface correctly.
        vm.assume(sender.code.length == 0);

        // Deploy an OpenZeppelin ERC-721 token contract.
        IERC721 token = _deployOpenZeppelinErc721Token(sender, tokenId);

        // Finally, the sender tries to deposit the token.
        // We expect it to fail because the sender hasn't approved the indirect transfer.
        vm.prank(sender);
        vm.expectRevert(_encodeErc721InsufficientApproval(tokenId));
        ERC721_PORTAL.depositERC721Token(
            token, _app, tokenId, baseLayerData, execLayerData
        );
    }

    function testOpenZeppelinErc721DepositRevertsWhenSenderIsNotTokenOwner(
        address sender,
        address owner,
        uint256 tokenId,
        bool setApprovalForAll,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external {
        // Assume sender is not the zero address.
        // Otherwise, the token contract raises `ERC721InvalidReceiver`.
        // This is a fair assumption, given that the private key of zero address is unknown.
        vm.assume(sender != address(0));

        // Assume sender and owner are different.
        // This ensures that one has the token, but the other doesn't.
        vm.assume(sender != owner);

        // Assume owner is an EOA.
        // Otherwise, the token contract raises `ERC721InvalidReceiver`
        // because it probably doesn't implement the interface correctly.
        vm.assume(owner.code.length == 0);

        // Deploy an OpenZeppelin ERC-721 token contract.
        IERC721 token = _deployOpenZeppelinErc721Token(owner, tokenId);

        vm.prank(owner);
        if (setApprovalForAll) {
            // Make the owner approve any transfer from the portal.
            token.setApprovalForAll(address(ERC721_PORTAL), true);
        } else {
            // Make the owner approve the token transfer from the portal.
            token.approve(address(ERC721_PORTAL), tokenId);
        }

        // Finally, the sender tries to deposit the token it doesn't own.
        // We expect it to fail because the sender doesn't own the token.
        vm.prank(sender);
        vm.expectRevert(_encodeErc721IncorrectOwner(sender, tokenId, owner));
        ERC721_PORTAL.depositERC721Token(
            token, _app, tokenId, baseLayerData, execLayerData
        );
    }

    function testOpenZeppelinErc721DepositRevertsWhenTokenIsNonexistent(
        address sender,
        uint256 tokenId,
        uint256 otherTokenId,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external {
        // Assume sender is not the zero address.
        // Otherwise, the token contract raises `ERC721InvalidReceiver`.
        // This is a fair assumption, given that the private key of zero address is unknown.
        vm.assume(sender != address(0));

        // Assume sender is an EOA.
        // Otherwise, the token contract raises `ERC721InvalidReceiver`
        // because it probably doesn't implement the interface correctly.
        vm.assume(sender.code.length == 0);

        // We assume the token IDs are different,
        // so that we can mine one and have the other as nonexistent.
        vm.assume(tokenId != otherTokenId);

        // Deploy an OpenZeppelin ERC-721 token contract.
        // We mine a token with ID `otherTokenId` and use `tokenId` for the transfer.
        IERC721 token = _deployOpenZeppelinErc721Token(sender, otherTokenId);

        // Make the sender approve any transfer from the portal.
        // Here, we cannot call `approve` because the token we are going to
        // transfer doesn't exist, so it would raise `ERC721NonexistentToken` here.
        vm.prank(sender);
        token.setApprovalForAll(address(ERC721_PORTAL), true);

        // Finally, the sender tries to deposit a nonexistent token.
        // We expect it to fail because the token doesn't exist.
        vm.prank(sender);
        vm.expectRevert(_encodeErc721NonexistentToken(tokenId));
        ERC721_PORTAL.depositERC721Token(
            token, _app, tokenId, baseLayerData, execLayerData
        );
    }

    function testOpenZeppelinErc721DepositSucceeds(
        address sender,
        uint256 tokenId,
        bool setApprovalForAll,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external {
        // We need to assume the sender is not the application contract
        // so that our accounting of tokens before and after makes sense.
        // It is also a fair assumption given that an application transfer
        // tokens to itself is a no-op.
        vm.assume(sender != address(_app));

        // Assume sender is not the zero address.
        // Otherwise, the token contract raises `ERC721InvalidReceiver`.
        // This is a fair assumption, given that the private key of zero address is unknown.
        vm.assume(sender != address(0));

        // Assume sender is an EOA.
        // Otherwise, the token contract raises `ERC721InvalidReceiver`
        // because it probably doesn't implement the interface correctly.
        vm.assume(sender.code.length == 0);

        // Deploy an OpenZeppelin ERC-721 token contract.
        IERC721 token = _deployOpenZeppelinErc721Token(sender, tokenId);

        vm.prank(sender);
        if (setApprovalForAll) {
            // Make the sender approve any transfer from the portal.
            token.setApprovalForAll(address(ERC721_PORTAL), true);
        } else {
            // Make the sender approve the token transfer from the portal.
            token.approve(address(ERC721_PORTAL), tokenId);
        }

        // We get the number of inputs as the expected input index
        // and also to check that the input count increases by 1.
        uint256 numOfInputsBefore = _app.getNumberOfInputs();

        // We encode the input to check against the InputAdded event to be emitted.
        bytes memory input = _encodeInput(
            numOfInputsBefore,
            address(ERC721_PORTAL),
            InputEncoding.encodeERC721Deposit(
                token, sender, tokenId, baseLayerData, execLayerData
            )
        );

        uint256 appBalanceBefore = token.balanceOf(address(_app));

        // Prior to the transfer, we make sure the sender owns the token.
        assertEq(token.ownerOf(tokenId), sender);

        // And then, we impersonate the sender.
        vm.prank(sender);

        // We make sure an InputAdded event is emitted.
        vm.expectEmit(true, false, false, true, address(_app));
        emit Inbox.InputAdded(numOfInputsBefore, input);

        // Finally, we make the deposit.
        ERC721_PORTAL.depositERC721Token(
            token, _app, tokenId, baseLayerData, execLayerData
        );

        uint256 appBalanceAfter = token.balanceOf(address(_app));
        uint256 numOfInputsAfter = _app.getNumberOfInputs();

        // Make sure that the app balance has increased by the transfer value
        // and that only one input was added in the deposit tx;
        // We also ensure that the app now owns the token.
        assertEq(appBalanceAfter, appBalanceBefore + 1);
        assertEq(numOfInputsAfter, numOfInputsBefore + 1);
        assertEq(token.ownerOf(tokenId), address(_app));
    }

    // ----------------------------
    // ERC-1155 Single Portal tests
    // ----------------------------

    function testErc1155SingleDepositWhenSafeTransferFromReturns(
        address sender,
        uint256 tokenId,
        uint256 value,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external {
        // First, we encode the `safeTransferFrom` call to be mocked.
        bytes memory safeTransferFrom =
            _encodeErc1155SafeTransferFrom(sender, tokenId, value, baseLayerData);

        // Second, we make the token mock return when
        // called with the expected arguments (`from`, `to`, `tokenId`, `value`, and `data`).
        vm.mockCall(TOKEN_MOCK, safeTransferFrom, abi.encode());

        // We cast the token mock as a ERC-1155 token contract
        // to signal that it implements the interface (although partially).
        IERC1155 token = IERC1155(TOKEN_MOCK);

        // We get the number of inputs as the expected input index
        // and also to check that the input count increases by 1.
        uint256 numOfInputsBefore = _app.getNumberOfInputs();

        // We encode the input to check against the InputAdded event to be emitted.
        bytes memory input = _encodeInput(
            numOfInputsBefore,
            address(ERC1155_SINGLE_PORTAL),
            InputEncoding.encodeSingleERC1155Deposit(
                token, sender, tokenId, value, baseLayerData, execLayerData
            )
        );

        // And then, we impersonate the sender.
        vm.prank(sender);

        // We make sure an InputAdded event is emitted.
        vm.expectEmit(true, false, false, true, address(_app));
        emit Inbox.InputAdded(numOfInputsBefore, input);

        // Finally, we make the deposit.
        ERC1155_SINGLE_PORTAL.depositSingleERC1155Token(
            token, _app, tokenId, value, baseLayerData, execLayerData
        );

        uint256 numOfInputsAfter = _app.getNumberOfInputs();

        // Make sure that the app has received exactly one input.
        assertEq(numOfInputsAfter, numOfInputsBefore + 1);
    }

    function testErc1155SingleDepositWhenSafeTransferFromReverts(
        address sender,
        uint256 tokenId,
        uint256 value,
        bytes calldata baseLayerData,
        bytes calldata execLayerData,
        bytes calldata errorData
    ) external {
        // First, we encode the `safeTransferFrom` call to be mocked.
        bytes memory safeTransferFrom =
            _encodeErc1155SafeTransferFrom(sender, tokenId, value, baseLayerData);

        // Second, we make the token mock return when
        // called with the expected arguments (`from`, `to`, `tokenId`, `value`, and `data`).
        vm.mockCallRevert(TOKEN_MOCK, safeTransferFrom, errorData);

        // We cast the token mock as a ERC-1155 token contract
        // to signal that it implements the interface (although partially).
        IERC1155 token = IERC1155(TOKEN_MOCK);

        // And then, we impersonate the sender.
        vm.prank(sender);

        // Finally, we try to make the deposit, expecting it to revert
        // with the same error raised by `safeTransferFrom`.
        vm.expectRevert(errorData);
        ERC1155_SINGLE_PORTAL.depositSingleERC1155Token(
            token, _app, tokenId, value, baseLayerData, execLayerData
        );
    }

    function testOpenZeppelinErc1155SingleDepositRevertsWhenSenderHasntGivenApprovalForAll(
        address sender,
        uint256 tokenId,
        uint256 value,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external {
        // Assume sender is not the zero address.
        // Otherwise, the token contract raises `ERC1155InvalidReceiver`.
        // This is a fair assumption, given that the private key of zero address is unknown.
        vm.assume(sender != address(0));

        // Assume sender is an EOA.
        // Otherwise, the token contract raises `ERC1155InvalidReceiver`
        // because it probably doesn't implement the interface correctly.
        vm.assume(sender.code.length == 0);

        // Deploy an OpenZeppelin ERC-1155 token contract.
        IERC1155 token = _deployOpenZeppelinErc1155Token(sender, tokenId, value);

        // Finally, the sender tries to deposit the token.
        // We expect it to revert because the sender hasn't given the portal
        // approval for transfering any of its ERC-1155 tokens.
        vm.prank(sender);
        vm.expectRevert(
            _encodeErc1155MissingApprovalForAll(address(ERC1155_SINGLE_PORTAL), sender)
        );
        ERC1155_SINGLE_PORTAL.depositSingleERC1155Token(
            token, _app, tokenId, value, baseLayerData, execLayerData
        );
    }

    function testOpenZeppelinErc1155SingleDepositRevertsWhenSenderHasInsufficientBalance(
        address sender,
        uint256 tokenId,
        uint256 value,
        uint256 balance,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external {
        // Assume sender is not the zero address.
        // Otherwise, the token contract raises `ERC1155InvalidReceiver`.
        // This is a fair assumption, given that the private key of zero address is unknown.
        vm.assume(sender != address(0));

        // Bound the value and balance.
        // We need 0 <= balance < value <= type(uint256).max
        balance = bound(balance, 0, type(uint256).max - 1);
        value = bound(value, balance + 1, type(uint256).max);

        // Assume sender is an EOA.
        // Otherwise, the token contract raises `ERC1155InvalidReceiver`
        // because it probably doesn't implement the interface correctly.
        vm.assume(sender.code.length == 0);

        // Deploy an OpenZeppelin ERC-1155 token contract.
        IERC1155 token = _deployOpenZeppelinErc1155Token(sender, tokenId, balance);

        // Then, we give the portal approval for handling any tokens on the sender's behalf.
        vm.prank(sender);
        token.setApprovalForAll(address(ERC1155_SINGLE_PORTAL), true);

        // Finally, the sender tries to deposit the token.
        // We expect it to revert because the sender doesn't have enough tokens.
        vm.prank(sender);
        vm.expectRevert(
            _encodeErc1155InsufficientBalance(sender, balance, value, tokenId)
        );
        ERC1155_SINGLE_PORTAL.depositSingleERC1155Token(
            token, _app, tokenId, value, baseLayerData, execLayerData
        );
    }

    function testOpenZeppelinErc1155SingleDeposit(
        address sender,
        uint256 tokenId,
        uint256 value,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external {
        // Assume sender is not the zero address.
        // Otherwise, the token contract raises `ERC1155InvalidReceiver`.
        // This is a fair assumption, given that the private key of zero address is unknown.
        vm.assume(sender != address(0));

        // Assume sender is an EOA.
        // Otherwise, the token contract raises `ERC1155InvalidReceiver`
        // because it probably doesn't implement the interface correctly.
        vm.assume(sender.code.length == 0);

        // Deploy an OpenZeppelin ERC-1155 token contract.
        IERC1155 token = _deployOpenZeppelinErc1155Token(sender, tokenId, value);

        // Then, we give the portal approval for handling any tokens on the sender's behalf.
        vm.prank(sender);
        token.setApprovalForAll(address(ERC1155_SINGLE_PORTAL), true);

        // Finally, the sender tries to deposit the token.
        vm.prank(sender);
        ERC1155_SINGLE_PORTAL.depositSingleERC1155Token(
            token, _app, tokenId, value, baseLayerData, execLayerData
        );
    }

    function testOpenZeppelinErc1155SingleDepositSucceeds(
        address sender,
        uint256 tokenId,
        uint256 value,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external {
        // Assume sender is not the zero address.
        // Otherwise, the token contract raises `ERC1155InvalidReceiver`.
        // This is a fair assumption, given that the private key of zero address is unknown.
        vm.assume(sender != address(0));

        // Assume sender is an EOA.
        // Otherwise, the token contract raises `ERC1155InvalidReceiver`
        // because it probably doesn't implement the interface correctly.
        vm.assume(sender.code.length == 0);

        // Deploy an OpenZeppelin ERC-1155 token contract.
        IERC1155 token = _deployOpenZeppelinErc1155Token(sender, tokenId, value);

        // Then, we give the portal approval for handling any tokens on the sender's behalf.
        vm.prank(sender);
        token.setApprovalForAll(address(ERC1155_SINGLE_PORTAL), true);

        // We get the number of inputs as the expected input index
        // and also to check that the input count increases by 1.
        uint256 numOfInputsBefore = _app.getNumberOfInputs();

        // We encode the input to check against the InputAdded event to be emitted.
        bytes memory input = _encodeInput(
            numOfInputsBefore,
            address(ERC1155_SINGLE_PORTAL),
            InputEncoding.encodeSingleERC1155Deposit(
                token, sender, tokenId, value, baseLayerData, execLayerData
            )
        );

        uint256 appBalanceBefore = token.balanceOf(address(_app), tokenId);

        // We make sure an InputAdded event is emitted.
        vm.expectEmit(true, false, false, true, address(_app));
        emit Inbox.InputAdded(numOfInputsBefore, input);

        // Finally, the sender tries to deposit the token.
        vm.prank(sender);
        ERC1155_SINGLE_PORTAL.depositSingleERC1155Token(
            token, _app, tokenId, value, baseLayerData, execLayerData
        );

        uint256 appBalanceAfter = token.balanceOf(address(_app), tokenId);
        uint256 numOfInputsAfter = _app.getNumberOfInputs();

        // Make sure that the app balance has increased by the transfer value
        // and that only one input was added in the deposit tx
        assertEq(appBalanceAfter, appBalanceBefore + value);
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

    /// @notice Encode an ERC-721 `safeTransferFrom` call from the application contract.
    /// @param sender The sender address
    /// @param tokenId The token ID
    /// @param data The extra data argument
    /// @return The encoded Solidity function call
    function _encodeErc721SafeTransferFrom(
        address sender,
        uint256 tokenId,
        bytes calldata data
    ) internal view returns (bytes memory) {
        return abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256,bytes)",
            sender,
            address(_app),
            tokenId,
            data
        );
    }

    /// @notice Encode an ERC-1155 `safeTransferFrom` call from the application contract.
    /// @param sender The sender address
    /// @param tokenId The token ID
    /// @param value The amount of tokens
    /// @param data The extra data argument
    /// @return The encoded Solidity function call
    function _encodeErc1155SafeTransferFrom(
        address sender,
        uint256 tokenId,
        uint256 value,
        bytes calldata data
    ) internal view returns (bytes memory) {
        return abi.encodeCall(
            IERC1155.safeTransferFrom, (sender, address(_app), tokenId, value, data)
        );
    }

    /// @notice Encode an `ERC20InsufficientAllowance` error related to the ERC-20 portal.
    /// @param insufficientAllowance The insufficient allowance
    /// @param neededAllowance The needed allowance
    /// @return The encoded Solidity error
    function _encodeErc20InsufficientAllowance(
        uint256 insufficientAllowance,
        uint256 neededAllowance
    ) internal view returns (bytes memory) {
        return abi.encodeWithSelector(
            IERC20Errors.ERC20InsufficientAllowance.selector,
            address(ERC20_PORTAL),
            insufficientAllowance,
            neededAllowance
        );
    }

    /// @notice Encode an `ERC20InsufficientBalance` error.
    /// @param tokenSender The token sender
    /// @param insufficientBalance The insufficient balance
    /// @param neededBalance The needed balance
    /// @return The encoded Solidity error
    function _encodeErc20InsufficientBalance(
        address tokenSender,
        uint256 insufficientBalance,
        uint256 neededBalance
    ) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            IERC20Errors.ERC20InsufficientBalance.selector,
            tokenSender,
            insufficientBalance,
            neededBalance
        );
    }

    /// @notice Encode an `ERC721InsufficientApproval` error related to the ERC-721 portal.
    /// @param tokenId The token ID
    /// @return The encoded Solidity error
    function _encodeErc721InsufficientApproval(uint256 tokenId)
        internal
        view
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IERC721Errors.ERC721InsufficientApproval.selector,
            address(ERC721_PORTAL),
            tokenId
        );
    }

    /// @notice Encode an `ERC721IncorrectOwner` error related to the ERC-721 portal.
    /// @param sender The token sender
    /// @param tokenId The token ID
    /// @param owner The token owner
    /// @return The encoded Solidity error
    function _encodeErc721IncorrectOwner(address sender, uint256 tokenId, address owner)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IERC721Errors.ERC721IncorrectOwner.selector, sender, tokenId, owner
        );
    }

    /// @notice Encode an `ERC721NonexistentToken` error.
    /// @param tokenId The nonexistent token ID
    /// @return The encoded Solidity error
    function _encodeErc721NonexistentToken(uint256 tokenId)
        internal
        pure
        returns (bytes memory)
    {
        return
            abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, tokenId);
    }

    /// @notice Encode an `ERC1155MissingApprovalForAll` error.
    /// @param operator The transfer operator
    /// @param owner The token owner
    /// @return The encoded Solidity error
    function _encodeErc1155MissingApprovalForAll(address operator, address owner)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IERC1155Errors.ERC1155MissingApprovalForAll.selector, operator, owner
        );
    }

    /// @notice Encode an `ERC1155InsufficientBalance` error.
    /// @param tokenSender The token sender
    /// @param insufficientBalance The insufficient balance
    /// @param neededBalance The needed balance
    /// @param tokenId The token ID
    /// @return The encoded Solidity error
    function _encodeErc1155InsufficientBalance(
        address tokenSender,
        uint256 insufficientBalance,
        uint256 neededBalance,
        uint256 tokenId
    ) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            IERC1155Errors.ERC1155InsufficientBalance.selector,
            tokenSender,
            insufficientBalance,
            neededBalance,
            tokenId
        );
    }

    /// @notice Deploy an OpenZeppelin's ERC-20 token contract.
    /// @param tokenOwner The account that holds all the token supply initially
    /// @param tokenSupply The token supply
    /// @return The ERC-20 token contract
    function _deployOpenZeppelinErc20Token(address tokenOwner, uint256 tokenSupply)
        internal
        returns (IERC20)
    {
        return new SimpleERC20(tokenOwner, tokenSupply);
    }

    /// @notice Deploy an OpenZeppelin's ERC-721 token contract.
    /// @param tokenOwner The account that holds all the token supply initially
    /// @param tokenId The token ID
    /// @return The ERC-721 token contract
    function _deployOpenZeppelinErc721Token(address tokenOwner, uint256 tokenId)
        internal
        returns (IERC721)
    {
        return new SimpleERC721(tokenOwner, tokenId);
    }

    /// @notice Deploy an OpenZeppelin's ERC-1155 token contract that mints a single type of token.
    /// @param tokenOwner The account that holds all the token supply initially
    /// @param tokenId The token ID
    /// @param tokenSupply The token supply
    /// @return The ERC-1155 token contract
    function _deployOpenZeppelinErc1155Token(
        address tokenOwner,
        uint256 tokenId,
        uint256 tokenSupply
    ) internal returns (IERC1155) {
        return new SimpleSingleERC1155(tokenOwner, tokenId, tokenSupply);
    }
}
