// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Test} from "forge-std-1.9.6/src/Test.sol";
import {Vm} from "forge-std-1.9.6/src/Vm.sol";

import {IERC1155} from "@openzeppelin-contracts-5.2.0/token/ERC1155/IERC1155.sol";
import {IERC1155Receiver} from
    "@openzeppelin-contracts-5.2.0/token/ERC1155/IERC1155Receiver.sol";

import {App} from "src/app/interfaces/App.sol";
import {IERC1155BatchPortal} from "src/portals/IERC1155BatchPortal.sol";
import {Inbox} from "src/app/interfaces/Inbox.sol";
import {InputEncoding} from "src/common/InputEncoding.sol";

import {SimpleBatchERC1155} from "test/util/SimpleERC1155.sol";
import {LibCannon} from "test/util/LibCannon.sol";

contract ERC1155BatchPortalTest is Test {
    using LibCannon for Vm;

    address _alice;
    App _appContract;
    IERC1155 _token;
    IERC1155BatchPortal _portal;

    function setUp() external {
        _alice = vm.addr(1);
        _appContract = App(vm.addr(2));
        _token = IERC1155(vm.addr(3));
        _portal = IERC1155BatchPortal(vm.getAddress("ERC1155BatchPortal"));
    }

    function testDeposit(
        uint256[] calldata tokenIds,
        uint256[] calldata values,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external {
        bytes memory safeBatchTransferFrom =
            _encodeSafeBatchTransferFrom(tokenIds, values, baseLayerData);

        vm.mockCall(address(_token), safeBatchTransferFrom, abi.encode());
        vm.expectCall(address(_token), safeBatchTransferFrom, 1);

        bytes memory payload =
            encodePayload(tokenIds, values, baseLayerData, execLayerData);

        bytes memory addInput = _encodeAddInput(payload);

        vm.mockCall(address(_appContract), addInput, abi.encode(bytes32(0)));
        vm.expectCall(address(_appContract), addInput, 1);

        vm.prank(_alice);
        _portal.depositBatchERC1155Token(
            _token, _appContract, tokenIds, values, baseLayerData, execLayerData
        );
    }

    function testTokenReverts(
        uint256[] calldata tokenIds,
        uint256[] calldata values,
        bytes calldata baseLayerData,
        bytes calldata execLayerData,
        bytes memory errorData
    ) external {
        bytes memory safeBatchTransferFrom =
            _encodeSafeBatchTransferFrom(tokenIds, values, baseLayerData);

        vm.mockCall(address(_token), safeBatchTransferFrom, abi.encode());
        vm.mockCallRevert(address(_token), safeBatchTransferFrom, errorData);

        bytes memory payload =
            encodePayload(tokenIds, values, baseLayerData, execLayerData);

        bytes memory addInput = _encodeAddInput(payload);

        vm.mockCall(address(_appContract), addInput, abi.encode(bytes32(0)));

        vm.expectRevert(errorData);

        vm.prank(_alice);
        _portal.depositBatchERC1155Token(
            _token, _appContract, tokenIds, values, baseLayerData, execLayerData
        );
    }

    function testAppReverts(
        uint256[] calldata tokenIds,
        uint256[] calldata values,
        bytes calldata baseLayerData,
        bytes calldata execLayerData,
        bytes memory errorData
    ) external {
        bytes memory safeBatchTransferFrom =
            _encodeSafeBatchTransferFrom(tokenIds, values, baseLayerData);

        vm.mockCall(address(_token), safeBatchTransferFrom, abi.encode());

        bytes memory payload =
            encodePayload(tokenIds, values, baseLayerData, execLayerData);

        bytes memory addInput = _encodeAddInput(payload);

        vm.mockCall(address(_appContract), addInput, abi.encode(bytes32(0)));
        vm.mockCallRevert(address(_appContract), addInput, errorData);

        vm.expectRevert(errorData);

        vm.prank(_alice);
        _portal.depositBatchERC1155Token(
            _token, _appContract, tokenIds, values, baseLayerData, execLayerData
        );
    }

    function testSimpleBatchERC1155(
        uint256[] calldata supplies,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external {
        // construct arrays of tokenIds and values
        uint256 numOfTokenIds = supplies.length;
        vm.assume(numOfTokenIds > 1);
        uint256[] memory tokenIds = new uint256[](numOfTokenIds);
        uint256[] memory values = new uint256[](numOfTokenIds);
        for (uint256 i; i < numOfTokenIds; ++i) {
            tokenIds[i] = i;
            values[i] = bound(i, 0, supplies[i]);
        }

        _token = new SimpleBatchERC1155(_alice, tokenIds, supplies);

        vm.startPrank(_alice);

        // Allow the portal to withdraw tokens from Alice
        _token.setApprovalForAll(address(_portal), true);

        bytes memory payload =
            this.encodePayload(tokenIds, values, baseLayerData, execLayerData);

        bytes memory addInput = _encodeAddInput(payload);

        bytes memory onERC1155Received =
            _encodeOnErc1155BatchReceived(tokenIds, values, baseLayerData);

        vm.mockCall(address(_appContract), addInput, abi.encode(bytes32(0)));

        vm.mockCall(
            address(_appContract),
            onERC1155Received,
            abi.encode(IERC1155Receiver.onERC1155BatchReceived.selector)
        );

        // balances before
        for (uint256 i; i < numOfTokenIds; ++i) {
            uint256 tokenId = tokenIds[i];
            uint256 supply = supplies[i];
            assertEq(_token.balanceOf(_alice, tokenId), supply);
            assertEq(_token.balanceOf(address(_appContract), tokenId), 0);
            assertEq(_token.balanceOf(address(_portal), tokenId), 0);
        }

        vm.expectCall(address(_appContract), addInput, 1);

        vm.expectEmit(true, true, true, true, address(_token));
        emit IERC1155.TransferBatch(
            address(_portal), _alice, address(_appContract), tokenIds, values
        );

        _portal.depositBatchERC1155Token(
            _token, _appContract, tokenIds, values, baseLayerData, execLayerData
        );
        vm.stopPrank();

        // balances after
        for (uint256 i; i < numOfTokenIds; ++i) {
            uint256 tokenId = tokenIds[i];
            uint256 value = values[i];
            uint256 supply = supplies[i];
            assertEq(_token.balanceOf(_alice, tokenId), supply - value);
            assertEq(_token.balanceOf(address(_appContract), tokenId), value);
            assertEq(_token.balanceOf(address(_portal), tokenId), 0);
        }
    }

    function encodePayload(
        uint256[] calldata tokenIds,
        uint256[] calldata values,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) public view returns (bytes memory) {
        return InputEncoding.encodeBatchERC1155Deposit(
            _token, _alice, tokenIds, values, baseLayerData, execLayerData
        );
    }

    function _encodeAddInput(bytes memory payload)
        internal
        pure
        returns (bytes memory input)
    {
        return abi.encodeCall(Inbox.addInput, (payload));
    }

    function _encodeSafeBatchTransferFrom(
        uint256[] calldata tokenIds,
        uint256[] calldata values,
        bytes calldata baseLayerData
    ) internal view returns (bytes memory) {
        return abi.encodeCall(
            IERC1155.safeBatchTransferFrom,
            (_alice, address(_appContract), tokenIds, values, baseLayerData)
        );
    }

    function _encodeOnErc1155BatchReceived(
        uint256[] memory tokenIds,
        uint256[] memory values,
        bytes calldata baseLayerData
    ) internal view returns (bytes memory) {
        return abi.encodeCall(
            IERC1155Receiver.onERC1155BatchReceived,
            (address(_portal), _alice, tokenIds, values, baseLayerData)
        );
    }
}
