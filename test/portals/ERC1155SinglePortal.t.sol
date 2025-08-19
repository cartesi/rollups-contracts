// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Test} from "forge-std-1.10.0/src/Test.sol";
import {Vm} from "forge-std-1.10.0/src/Vm.sol";

import {IERC1155} from "@openzeppelin-contracts-5.2.0/token/ERC1155/IERC1155.sol";
import {IERC1155Receiver} from
    "@openzeppelin-contracts-5.2.0/token/ERC1155/IERC1155Receiver.sol";

import {App} from "src/app/interfaces/App.sol";
import {IERC1155SinglePortal} from "src/portals/IERC1155SinglePortal.sol";
import {Inbox} from "src/app/interfaces/Inbox.sol";
import {InputEncoding} from "src/common/InputEncoding.sol";

import {SimpleSingleERC1155} from "test/util/SimpleERC1155.sol";
import {LibCannon} from "test/util/LibCannon.sol";

contract ERC1155SinglePortalTest is Test {
    using LibCannon for Vm;

    address _alice;
    App _appContract;
    IERC1155 _token;
    IERC1155SinglePortal _portal;

    function setUp() external {
        _alice = vm.addr(1);
        _appContract = App(vm.addr(2));
        _token = IERC1155(vm.addr(3));
        _portal = IERC1155SinglePortal(vm.getAddress("ERC1155SinglePortal"));
    }

    function testDeposit(
        uint256 tokenId,
        uint256 value,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external {
        bytes memory safeTransferFrom =
            _encodeSafeTransferFrom(tokenId, value, baseLayerData);

        vm.mockCall(address(_token), safeTransferFrom, abi.encode());
        vm.expectCall(address(_token), safeTransferFrom, 1);

        bytes memory payload =
            _encodePayload(tokenId, value, baseLayerData, execLayerData);

        bytes memory addInput = _encodeAddInput(payload);

        vm.mockCall(address(_appContract), addInput, abi.encode(bytes32(0)));
        vm.expectCall(address(_appContract), addInput, 1);

        vm.prank(_alice);
        _portal.depositSingleERC1155Token(
            _token, _appContract, tokenId, value, baseLayerData, execLayerData
        );
    }

    function testTokenReverts(
        uint256 tokenId,
        uint256 value,
        bytes calldata baseLayerData,
        bytes calldata execLayerData,
        bytes memory errorData
    ) external {
        bytes memory safeTransferFrom =
            _encodeSafeTransferFrom(tokenId, value, baseLayerData);

        vm.mockCall(address(_token), safeTransferFrom, abi.encode());
        vm.mockCallRevert(address(_token), safeTransferFrom, errorData);

        bytes memory payload =
            _encodePayload(tokenId, value, baseLayerData, execLayerData);

        bytes memory addInput = _encodeAddInput(payload);

        vm.mockCall(address(_appContract), addInput, abi.encode(bytes32(0)));

        vm.expectRevert(errorData);

        vm.prank(_alice);
        _portal.depositSingleERC1155Token(
            _token, _appContract, tokenId, value, baseLayerData, execLayerData
        );
    }

    function testAppReverts(
        uint256 tokenId,
        uint256 value,
        bytes calldata baseLayerData,
        bytes calldata execLayerData,
        bytes memory errorData
    ) external {
        bytes memory safeTransferFrom =
            _encodeSafeTransferFrom(tokenId, value, baseLayerData);

        vm.mockCall(address(_token), safeTransferFrom, abi.encode());

        bytes memory payload =
            _encodePayload(tokenId, value, baseLayerData, execLayerData);

        bytes memory addInput = _encodeAddInput(payload);

        vm.mockCall(address(_appContract), addInput, abi.encode(bytes32(0)));
        vm.mockCallRevert(address(_appContract), addInput, errorData);

        vm.expectRevert(errorData);

        vm.prank(_alice);
        _portal.depositSingleERC1155Token(
            _token, _appContract, tokenId, value, baseLayerData, execLayerData
        );
    }

    function testSimpleSingleERC1155(
        uint256 tokenId,
        uint256 supply,
        uint256 value,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external {
        value = bound(value, 0, supply);
        _token = new SimpleSingleERC1155(_alice, tokenId, supply);

        vm.startPrank(_alice);

        // Allow the portal to withdraw tokens from Alice
        _token.setApprovalForAll(address(_portal), true);

        bytes memory payload =
            _encodePayload(tokenId, value, baseLayerData, execLayerData);

        bytes memory addInput = _encodeAddInput(payload);

        bytes memory onERC1155Received =
            _encodeOnErc1155Received(tokenId, value, baseLayerData);

        vm.mockCall(address(_appContract), addInput, abi.encode(bytes32(0)));

        vm.mockCall(
            address(_appContract),
            onERC1155Received,
            abi.encode(IERC1155Receiver.onERC1155Received.selector)
        );

        // balances before
        assertEq(_token.balanceOf(_alice, tokenId), supply);
        assertEq(_token.balanceOf(address(_appContract), tokenId), 0);
        assertEq(_token.balanceOf(address(_portal), tokenId), 0);

        vm.expectCall(address(_appContract), addInput, 1);

        vm.expectEmit(true, true, true, true, address(_token));
        emit IERC1155.TransferSingle(
            address(_portal), _alice, address(_appContract), tokenId, value
        );

        _portal.depositSingleERC1155Token(
            _token, _appContract, tokenId, value, baseLayerData, execLayerData
        );
        vm.stopPrank();

        // balances after
        assertEq(_token.balanceOf(_alice, tokenId), supply - value);
        assertEq(_token.balanceOf(address(_appContract), tokenId), value);
        assertEq(_token.balanceOf(address(_portal), tokenId), 0);
    }

    function _encodePayload(
        uint256 tokenId,
        uint256 value,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) internal view returns (bytes memory) {
        return InputEncoding.encodeSingleERC1155Deposit(
            _token, _alice, tokenId, value, baseLayerData, execLayerData
        );
    }

    function _encodeAddInput(bytes memory payload)
        internal
        pure
        returns (bytes memory input)
    {
        return abi.encodeCall(Inbox.addInput, (payload));
    }

    function _encodeSafeTransferFrom(
        uint256 tokenId,
        uint256 value,
        bytes calldata baseLayerData
    ) internal view returns (bytes memory) {
        return abi.encodeCall(
            IERC1155.safeTransferFrom,
            (_alice, address(_appContract), tokenId, value, baseLayerData)
        );
    }

    function _encodeOnErc1155Received(
        uint256 tokenId,
        uint256 value,
        bytes calldata baseLayerData
    ) internal view returns (bytes memory) {
        return abi.encodeCall(
            IERC1155Receiver.onERC1155Received,
            (address(_portal), _alice, tokenId, value, baseLayerData)
        );
    }
}
