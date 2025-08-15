// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Test} from "forge-std-1.9.6/src/Test.sol";
import {Vm} from "forge-std-1.9.6/src/Vm.sol";

import {IERC721} from "@openzeppelin-contracts-5.2.0/token/ERC721/IERC721.sol";
import {IERC721Receiver} from
    "@openzeppelin-contracts-5.2.0/token/ERC721/IERC721Receiver.sol";

import {App} from "src/app/interfaces/App.sol";
import {IERC721Portal} from "src/portals/IERC721Portal.sol";
import {Inbox} from "src/app/interfaces/Inbox.sol";
import {InputEncoding} from "src/common/InputEncoding.sol";

import {SimpleERC721} from "test/util/SimpleERC721.sol";
import {LibCannon} from "test/util/LibCannon.sol";

contract ERC721PortalTest is Test {
    using LibCannon for Vm;

    address _alice;
    App _appContract;
    IERC721 _token;
    IERC721Portal _portal;

    function setUp() public {
        _alice = vm.addr(1);
        _appContract = App(vm.addr(2));
        _token = IERC721(vm.addr(3));
        _portal = IERC721Portal(vm.getAddress("ERC721Portal"));
    }

    function testDeposit(
        uint256 tokenId,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) public {
        bytes memory safeTransferFrom = _encodeSafeTransferFrom(tokenId, baseLayerData);

        vm.mockCall(address(_token), safeTransferFrom, abi.encode());
        vm.expectCall(address(_token), safeTransferFrom, 1);

        bytes memory payload =
            _encodePayload(_token, tokenId, baseLayerData, execLayerData);

        bytes memory addInput = _encodeAddInput(payload);

        vm.mockCall(address(_appContract), addInput, abi.encode(bytes32(0)));
        vm.expectCall(address(_appContract), addInput, 1);

        vm.prank(_alice);
        _portal.depositERC721Token(
            _token, _appContract, tokenId, baseLayerData, execLayerData
        );
    }

    function testTokenReverts(
        uint256 tokenId,
        bytes calldata baseLayerData,
        bytes calldata execLayerData,
        bytes memory errorData
    ) public {
        bytes memory safeTransferFrom = _encodeSafeTransferFrom(tokenId, baseLayerData);

        vm.mockCallRevert(address(_token), safeTransferFrom, errorData);

        bytes memory payload =
            _encodePayload(_token, tokenId, baseLayerData, execLayerData);

        bytes memory addInput = _encodeAddInput(payload);

        vm.mockCall(address(_appContract), addInput, abi.encode(bytes32(0)));

        vm.expectRevert(errorData);

        vm.prank(_alice);
        _portal.depositERC721Token(
            _token, _appContract, tokenId, baseLayerData, execLayerData
        );
    }

    function testAppReverts(
        uint256 tokenId,
        bytes calldata baseLayerData,
        bytes calldata execLayerData,
        bytes memory errorData
    ) public {
        bytes memory safeTransferFrom = _encodeSafeTransferFrom(tokenId, baseLayerData);

        vm.mockCall(address(_token), safeTransferFrom, abi.encode());

        bytes memory payload =
            _encodePayload(_token, tokenId, baseLayerData, execLayerData);

        bytes memory addInput = _encodeAddInput(payload);

        vm.mockCallRevert(address(_appContract), addInput, errorData);

        vm.expectRevert(errorData);

        vm.prank(_alice);
        _portal.depositERC721Token(
            _token, _appContract, tokenId, baseLayerData, execLayerData
        );
    }

    function testSimpleERC721(
        uint256 tokenId,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) public {
        SimpleERC721 token = new SimpleERC721(_alice, tokenId);

        vm.startPrank(_alice);

        token.approve(address(_portal), tokenId);

        // token owner before
        assertEq(token.ownerOf(tokenId), _alice);

        bytes memory payload =
            _encodePayload(token, tokenId, baseLayerData, execLayerData);

        bytes memory addInput = _encodeAddInput(payload);

        bytes memory onERC721Received = _encodeOnErc721Received(tokenId, baseLayerData);

        vm.mockCall(address(_appContract), addInput, abi.encode(bytes32(0)));

        vm.mockCall(
            address(_appContract),
            onERC721Received,
            abi.encode(IERC721Receiver.onERC721Received.selector)
        );

        vm.expectCall(address(_appContract), addInput, 1);

        vm.expectEmit(true, true, true, false, address(token));
        emit IERC721.Transfer(_alice, address(_appContract), tokenId);

        _portal.depositERC721Token(
            token, _appContract, tokenId, baseLayerData, execLayerData
        );

        vm.stopPrank();

        // token owner after
        assertEq(token.ownerOf(tokenId), address(_appContract));
    }

    function _encodePayload(
        IERC721 token,
        uint256 tokenId,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) internal view returns (bytes memory) {
        return InputEncoding.encodeERC721Deposit(
            token, _alice, tokenId, baseLayerData, execLayerData
        );
    }

    function _encodeAddInput(bytes memory payload)
        internal
        pure
        returns (bytes memory input)
    {
        return abi.encodeCall(Inbox.addInput, (payload));
    }

    function _encodeSafeTransferFrom(uint256 tokenId, bytes calldata baseLayerData)
        internal
        view
        returns (bytes memory)
    {
        return abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256,bytes)",
            _alice,
            address(_appContract),
            tokenId,
            baseLayerData
        );
    }

    function _encodeOnErc721Received(uint256 tokenId, bytes calldata baseLayerData)
        internal
        view
        returns (bytes memory)
    {
        return abi.encodeCall(
            IERC721Receiver.onERC721Received,
            (address(_portal), _alice, tokenId, baseLayerData)
        );
    }
}
