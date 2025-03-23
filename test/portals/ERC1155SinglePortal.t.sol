// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {ERC1155} from "@openzeppelin-contracts-5.2.0/token/ERC1155/ERC1155.sol";
import {IERC1155} from "@openzeppelin-contracts-5.2.0/token/ERC1155/IERC1155.sol";

import {ERC1155SinglePortal} from "src/portals/ERC1155SinglePortal.sol";
import {IERC1155SinglePortal} from "src/portals/IERC1155SinglePortal.sol";
import {IInputBox} from "src/inputs/IInputBox.sol";
import {InputEncoding} from "src/common/InputEncoding.sol";

import {Test} from "forge-std-1.9.6/src/Test.sol";

import {SimpleSingleERC1155} from "../util/SimpleERC1155.sol";

contract ERC1155SinglePortalTest is Test {
    address _alice;
    address _appContract;
    IERC1155 _token;
    IInputBox _inputBox;
    IERC1155SinglePortal _portal;

    function setUp() public {
        _alice = vm.addr(1);
        _appContract = vm.addr(2);
        _token = IERC1155(vm.addr(3));
        _inputBox = IInputBox(vm.addr(4));
        _portal = new ERC1155SinglePortal(_inputBox);
    }

    function testGetInputBox() public view {
        assertEq(address(_portal.getInputBox()), address(_inputBox));
    }

    function testDeposit(
        uint256 tokenId,
        uint256 value,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) public {
        bytes memory safeTransferFrom =
            _encodeSafeTransferFrom(tokenId, value, baseLayerData);

        vm.mockCall(address(_token), safeTransferFrom, abi.encode());
        vm.expectCall(address(_token), safeTransferFrom, 1);

        bytes memory payload =
            _encodePayload(tokenId, value, baseLayerData, execLayerData);

        bytes memory addInput = _encodeAddInput(payload);

        vm.mockCall(address(_inputBox), addInput, abi.encode(bytes32(0)));
        vm.expectCall(address(_inputBox), addInput, 1);

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
    ) public {
        bytes memory safeTransferFrom =
            _encodeSafeTransferFrom(tokenId, value, baseLayerData);

        vm.mockCall(address(_token), safeTransferFrom, abi.encode());
        vm.mockCallRevert(address(_token), safeTransferFrom, errorData);

        bytes memory payload =
            _encodePayload(tokenId, value, baseLayerData, execLayerData);

        bytes memory addInput = _encodeAddInput(payload);

        vm.mockCall(address(_inputBox), addInput, abi.encode(bytes32(0)));

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
    ) public {
        value = bound(value, 0, supply);
        _token = new SimpleSingleERC1155(_alice, tokenId, supply);

        vm.startPrank(_alice);

        // Allow the portal to withdraw tokens from Alice
        _token.setApprovalForAll(address(_portal), true);

        bytes memory payload =
            _encodePayload(tokenId, value, baseLayerData, execLayerData);

        bytes memory addInput = _encodeAddInput(payload);

        vm.mockCall(address(_inputBox), addInput, abi.encode(bytes32(0)));

        // balances before
        assertEq(_token.balanceOf(_alice, tokenId), supply);
        assertEq(_token.balanceOf(_appContract, tokenId), 0);
        assertEq(_token.balanceOf(address(_portal), tokenId), 0);

        vm.expectCall(address(_inputBox), addInput, 1);

        vm.expectEmit(true, true, true, true, address(_token));
        emit IERC1155.TransferSingle(
            address(_portal), _alice, _appContract, tokenId, value
        );

        _portal.depositSingleERC1155Token(
            _token, _appContract, tokenId, value, baseLayerData, execLayerData
        );
        vm.stopPrank();

        // balances after
        assertEq(_token.balanceOf(_alice, tokenId), supply - value);
        assertEq(_token.balanceOf(_appContract, tokenId), value);
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

    function _encodeAddInput(bytes memory payload) internal view returns (bytes memory) {
        return abi.encodeCall(IInputBox.addInput, (_appContract, payload));
    }

    function _encodeSafeTransferFrom(
        uint256 tokenId,
        uint256 value,
        bytes calldata baseLayerData
    ) internal view returns (bytes memory) {
        return abi.encodeCall(
            IERC1155.safeTransferFrom,
            (_alice, _appContract, tokenId, value, baseLayerData)
        );
    }
}
