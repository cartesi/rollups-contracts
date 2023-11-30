// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title ERC-20 Portal Test
pragma solidity ^0.8.8;

import {Test} from "forge-std/Test.sol";
import {ERC20Portal} from "contracts/portals/ERC20Portal.sol";
import {IERC20Portal} from "contracts/portals/IERC20Portal.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IInputBox} from "contracts/inputs/IInputBox.sol";
import {InputBox} from "contracts/inputs/InputBox.sol";
import {IInputRelay} from "contracts/inputs/IInputRelay.sol";

contract NormalToken is ERC20 {
    constructor(
        address _tokenOwner,
        uint256 _initialSupply
    ) ERC20("NormalToken", "NORMAL") {
        _mint(_tokenOwner, _initialSupply);
    }
}

contract UntransferableToken is ERC20 {
    constructor(
        address _tokenOwner,
        uint256 _initialSupply
    ) ERC20("UntransferableToken", "UTFAB") {
        _mint(_tokenOwner, _initialSupply);
    }

    function transfer(address, uint256) public pure override returns (bool) {
        return false;
    }

    function transferFrom(
        address,
        address,
        uint256
    ) public pure override returns (bool) {
        return false;
    }
}

contract RevertingToken is ERC20 {
    constructor(
        address _tokenOwner,
        uint256 _initialSupply
    ) ERC20("RevertingToken", "REVERT") {
        _mint(_tokenOwner, _initialSupply);
    }

    function transfer(address, uint256) public pure override returns (bool) {
        revert();
    }

    function transferFrom(
        address,
        address,
        uint256
    ) public pure override returns (bool) {
        revert();
    }
}

contract WatcherToken is ERC20 {
    IInputBox inputBox;

    event WatchedTransfer(
        address from,
        address to,
        uint256 amount,
        uint256 numberOfInputs
    );

    constructor(
        IInputBox _inputBox,
        address _tokenOwner,
        uint256 _initialSupply
    ) ERC20("WatcherToken", "WTCHR") {
        inputBox = _inputBox;
        _mint(_tokenOwner, _initialSupply);
    }

    function transfer(
        address _to,
        uint256 _amount
    ) public override returns (bool) {
        emit WatchedTransfer(
            msg.sender,
            _to,
            _amount,
            inputBox.getNumberOfInputs(_to)
        );
        return super.transfer(_to, _amount);
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) public override returns (bool) {
        emit WatchedTransfer(
            _from,
            _to,
            _amount,
            inputBox.getNumberOfInputs(_to)
        );
        return super.transferFrom(_from, _to, _amount);
    }
}

contract ERC20PortalTest is Test {
    IInputBox inputBox;
    IERC20Portal portal;
    IERC20 token;
    address alice;
    address dapp;

    event InputAdded(
        address indexed dapp,
        uint256 indexed inputIndex,
        address sender,
        bytes input
    );
    event WatchedTransfer(
        address from,
        address to,
        uint256 amount,
        uint256 numberOfInputs
    );

    function setUp() public {
        inputBox = new InputBox();
        portal = new ERC20Portal(inputBox);
        alice = vm.addr(1);
        dapp = vm.addr(2);
    }

    function testSupportsInterface(bytes4 _randomInterfaceId) public {
        assertTrue(portal.supportsInterface(type(IERC20Portal).interfaceId));
        assertTrue(portal.supportsInterface(type(IInputRelay).interfaceId));
        assertTrue(portal.supportsInterface(type(IERC165).interfaceId));

        assertFalse(portal.supportsInterface(bytes4(0xffffffff)));

        vm.assume(_randomInterfaceId != type(IERC20Portal).interfaceId);
        vm.assume(_randomInterfaceId != type(IInputRelay).interfaceId);
        vm.assume(_randomInterfaceId != type(IERC165).interfaceId);
        assertFalse(portal.supportsInterface(_randomInterfaceId));
    }

    function testGetInputBox() public {
        assertEq(address(portal.getInputBox()), address(inputBox));
    }

    function testERC20Deposit(uint256 _amount, bytes calldata _data) public {
        // Create a normal token
        token = new NormalToken(alice, _amount);

        // Construct the ERC-20 deposit input
        bytes memory input = abi.encodePacked(token, alice, _amount, _data);

        vm.startPrank(alice);

        // Allow the portal to withdraw `_amount` tokens from Alice
        token.approve(address(portal), _amount);

        // Save the ERC-20 token balances
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 dappBalanceBefore = token.balanceOf(dapp);
        uint256 portalBalanceBefore = token.balanceOf(address(portal));

        // Expect InputAdded to be emitted with the right arguments
        vm.expectEmit(true, true, false, true, address(inputBox));
        emit InputAdded(dapp, 0, address(portal), input);

        // Transfer ERC-20 tokens to the DApp via the portal
        portal.depositERC20Tokens(token, dapp, _amount, _data);
        vm.stopPrank();

        // Check the balances after the deposit
        assertEq(token.balanceOf(alice), aliceBalanceBefore - _amount);
        assertEq(token.balanceOf(dapp), dappBalanceBefore + _amount);
        assertEq(token.balanceOf(address(portal)), portalBalanceBefore);

        // Check the DApp's input box
        assertEq(inputBox.getNumberOfInputs(dapp), 1);
    }

    function testRevertsOperationDidNotSucceed(
        uint256 _amount,
        bytes calldata _data
    ) public {
        // Create untransferable token
        token = new UntransferableToken(alice, _amount);

        vm.startPrank(alice);

        token.approve(address(portal), _amount);

        // Save the ERC-20 token balances
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 dappBalanceBefore = token.balanceOf(dapp);
        uint256 portalBalanceBefore = token.balanceOf(address(portal));

        // Transfer ERC-20 tokens to the DApp via the portal
        vm.expectRevert("SafeERC20: ERC20 operation did not succeed");
        portal.depositERC20Tokens(token, dapp, _amount, _data);
        vm.stopPrank();

        // Same balances as before
        assertEq(token.balanceOf(alice), aliceBalanceBefore);
        assertEq(token.balanceOf(dapp), dappBalanceBefore);
        assertEq(token.balanceOf(address(portal)), portalBalanceBefore);

        // No input added
        assertEq(inputBox.getNumberOfInputs(dapp), 0);
    }

    function testRevertsNonContract(
        uint256 _amount,
        bytes calldata _data
    ) public {
        // Use an EOA as token
        token = IERC20(vm.addr(3));

        vm.startPrank(alice);

        // Transfer ERC-20 tokens to the DApp via the portal
        vm.expectRevert("Address: call to non-contract");
        portal.depositERC20Tokens(token, dapp, _amount, _data);
        vm.stopPrank();

        // No input added
        assertEq(inputBox.getNumberOfInputs(dapp), 0);
    }

    function testRevertsLowLevelCallFailed(
        uint256 _amount,
        bytes calldata _data
    ) public {
        // Create bad token
        token = new RevertingToken(alice, _amount);

        vm.startPrank(alice);

        token.approve(address(portal), _amount);

        // Transfer ERC-20 tokens to the DApp via the portal
        vm.expectRevert("SafeERC20: low-level call failed");
        portal.depositERC20Tokens(token, dapp, _amount, _data);
        vm.stopPrank();

        // No input added
        assertEq(inputBox.getNumberOfInputs(dapp), 0);
    }

    function testRevertsInsufficientAllowance(
        uint256 _amount,
        bytes calldata _data
    ) public {
        // Anyone can transfer 0 tokens :-)
        vm.assume(_amount > 0);

        // Create a normal token
        token = new NormalToken(alice, _amount);

        vm.startPrank(alice);

        // Expect deposit to revert with message
        vm.expectRevert("ERC20: insufficient allowance");
        portal.depositERC20Tokens(token, dapp, _amount, _data);
        vm.stopPrank();

        // Check the DApp's input box
        assertEq(inputBox.getNumberOfInputs(dapp), 0);
    }

    function testRevertsInsufficientBalance(
        uint256 _amount,
        bytes calldata _data
    ) public {
        // Check if `_amount + 1` won't overflow
        vm.assume(_amount < type(uint256).max);

        // Create a normal token
        token = new NormalToken(alice, _amount);

        vm.startPrank(alice);

        // Allow the portal to withdraw `_amount+1` tokens from Alice
        token.approve(address(portal), _amount + 1);

        // Expect deposit to revert with message
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        portal.depositERC20Tokens(token, dapp, _amount + 1, _data);
        vm.stopPrank();

        // Check the DApp's input box
        assertEq(inputBox.getNumberOfInputs(dapp), 0);
    }

    function testNumberOfInputs(uint256 _amount, bytes calldata _data) public {
        // Create a token that records the number of inputs it has received
        token = new WatcherToken(inputBox, alice, _amount);

        vm.startPrank(alice);

        // Allow the portal to withdraw `_amount` tokens from Alice
        token.approve(address(portal), _amount);

        // Save number of inputs before the deposit
        uint256 numberOfInputsBefore = inputBox.getNumberOfInputs(dapp);

        // Expect token to be called when no input was added yet
        vm.expectEmit(false, false, false, true, address(token));
        emit WatchedTransfer(
            alice,
            address(dapp),
            _amount,
            numberOfInputsBefore
        );

        // Transfer ERC-20 tokens to DApp
        portal.depositERC20Tokens(token, dapp, _amount, _data);
        vm.stopPrank();

        // Expect new input
        assertEq(inputBox.getNumberOfInputs(dapp), numberOfInputsBefore + 1);
    }
}

contract ERC20PortalHandler is Test {
    IERC20Portal portal;
    IERC20 token;
    IInputBox inputBox;
    address[] public dapps;
    mapping(address => uint256) public dappBalances;
    mapping(address => uint256) public dappNumInputs;

    constructor(IERC20Portal _portal, IERC20 _token) {
        portal = _portal;
        token = _token;
        inputBox = portal.getInputBox();
    }

    function depositERC20Tokens(
        address _dapp,
        uint256 _amount,
        bytes calldata _execLayerData
    ) external {
        address sender = msg.sender;
        if (
            _dapp == address(0) ||
            sender == address(0) ||
            _dapp == address(this) ||
            sender == address(portal) ||
            _dapp == address(portal)
        ) return;
        _amount = bound(_amount, 0, token.balanceOf(address(this)));

        // fund sender
        require(token.transfer(sender, _amount), "token transfer fail");
        vm.prank(sender);
        token.approve(address(portal), _amount);

        // balance before the deposit
        uint256 senderBalanceBefore = token.balanceOf(sender);
        uint256 dappBalanceBefore = token.balanceOf(_dapp);
        // balance of the portal is 0 all the time during tests
        assertEq(token.balanceOf(address(portal)), 0);

        vm.prank(sender);
        portal.depositERC20Tokens(token, _dapp, _amount, _execLayerData);

        // Check the balances after the deposit
        assertEq(token.balanceOf(sender), senderBalanceBefore - _amount);
        assertEq(token.balanceOf(_dapp), dappBalanceBefore + _amount);
        assertEq(token.balanceOf(address(portal)), 0);

        dapps.push(_dapp);
        dappBalances[_dapp] += _amount;
        assertEq(++dappNumInputs[_dapp], inputBox.getNumberOfInputs(_dapp));
    }

    function getNumDapps() external view returns (uint256) {
        return dapps.length;
    }
}

contract ERC20PortalInvariantTest is Test {
    InputBox inputBox;
    ERC20Portal portal;
    NormalToken token;
    ERC20PortalHandler handler;
    uint256 constant tokenSupply = type(uint256).max;

    function setUp() public {
        inputBox = new InputBox();
        portal = new ERC20Portal(inputBox);
        token = new NormalToken(address(this), tokenSupply);
        handler = new ERC20PortalHandler(portal, token);
        // transfer all tokens to handler
        require(
            token.transfer(address(handler), tokenSupply),
            "token transfer fail"
        );

        targetContract(address(handler));
    }

    function invariantTests() external {
        for (uint256 i; i < handler.getNumDapps(); ++i) {
            address dapp = handler.dapps(i);
            assertEq(token.balanceOf(dapp), handler.dappBalances(dapp));
            uint256 numInputs = inputBox.getNumberOfInputs(dapp);
            assertEq(numInputs, handler.dappNumInputs(dapp));
        }
    }
}
