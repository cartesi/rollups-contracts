// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";

import {InputEncoding} from "src/common/InputEncoding.sol";
import {IInputBox} from "src/inputs/IInputBox.sol";
import {ERC20Portal} from "src/portals/ERC20Portal.sol";
import {IERC20Portal} from "src/portals/IERC20Portal.sol";

import {Test} from "forge-std-1.9.6/src/Test.sol";

import {SimpleERC20} from "../util/SimpleERC20.sol";

contract ERC20PortalTest is Test {
    address _alice;
    address _appContract;
    IInputBox _inputBox;
    IERC20 _token;
    IERC20Portal _portal;

    function setUp() public {
        _alice = vm.addr(1);
        _appContract = vm.addr(2);
        _inputBox = IInputBox(vm.addr(3));
        _token = IERC20(vm.addr(4));
        _portal = new ERC20Portal(_inputBox);
    }

    function testGetInputBox() public view {
        assertEq(address(_portal.getInputBox()), address(_inputBox));
    }

    function testTokenReturnsTrue(uint256 value, bytes calldata data) public {
        bytes memory transferFrom = _encodeTransferFrom(value);

        vm.mockCall(address(_token), transferFrom, abi.encode(true));

        bytes memory payload = _encodePayload(_token, value, data);

        bytes memory addInput = _encodeAddInput(payload);

        vm.mockCall(address(_inputBox), addInput, abi.encode(bytes32(0)));

        vm.expectCall(address(_token), transferFrom, 1);

        vm.expectCall(address(_inputBox), addInput, 1);

        vm.prank(_alice);
        _portal.depositERC20Tokens(_token, _appContract, value, data);
    }

    function testTokenReturnsFalse(uint256 value, bytes calldata data) public {
        bytes memory transferFrom = _encodeTransferFrom(value);

        vm.mockCall(address(_token), transferFrom, abi.encode(false));

        bytes memory payload = _encodePayload(_token, value, data);

        bytes memory addInput = _encodeAddInput(payload);

        vm.mockCall(address(_inputBox), addInput, abi.encode(bytes32(0)));

        vm.expectRevert(IERC20Portal.ERC20TransferFailed.selector);

        vm.prank(_alice);
        _portal.depositERC20Tokens(_token, _appContract, value, data);
    }

    function testTokenReverts(uint256 value, bytes calldata data, bytes memory errorData)
        public
    {
        bytes memory transferFrom = _encodeTransferFrom(value);

        vm.mockCallRevert(address(_token), transferFrom, errorData);

        bytes memory payload = _encodePayload(_token, value, data);

        bytes memory addInput = _encodeAddInput(payload);

        vm.mockCall(address(_inputBox), addInput, abi.encode(bytes32(0)));

        vm.expectRevert(errorData);

        vm.prank(_alice);
        _portal.depositERC20Tokens(_token, _appContract, value, data);
    }

    function testSimpleERC20(uint256 supply, uint256 value, bytes calldata data) public {
        value = bound(value, 0, supply);

        SimpleERC20 token = new SimpleERC20(_alice, supply);

        bytes memory payload = _encodePayload(token, value, data);

        bytes memory addInput = _encodeAddInput(payload);

        vm.startPrank(_alice);

        token.approve(address(_portal), value);

        vm.mockCall(address(_inputBox), addInput, abi.encode(bytes32(0)));

        // balances before
        assertEq(token.balanceOf(_alice), supply);
        assertEq(token.balanceOf(_appContract), 0);
        assertEq(token.balanceOf(address(_portal)), 0);

        vm.expectCall(address(_inputBox), addInput, 1);

        vm.expectEmit(true, true, false, true, address(token));
        emit IERC20.Transfer(_alice, _appContract, value);

        // deposit tokens
        _portal.depositERC20Tokens(token, _appContract, value, data);

        vm.stopPrank();

        // balances after
        assertEq(token.balanceOf(_alice), supply - value);
        assertEq(token.balanceOf(_appContract), value);
        assertEq(token.balanceOf(address(_portal)), 0);
    }

    function _encodePayload(IERC20 token, uint256 value, bytes calldata data)
        internal
        view
        returns (bytes memory)
    {
        return InputEncoding.encodeERC20Deposit(token, _alice, value, data);
    }

    function _encodeTransferFrom(uint256 value) internal view returns (bytes memory) {
        return abi.encodeCall(IERC20.transferFrom, (_alice, _appContract, value));
    }

    function _encodeAddInput(bytes memory payload) internal view returns (bytes memory) {
        return abi.encodeCall(IInputBox.addInput, (_appContract, payload));
    }
}
