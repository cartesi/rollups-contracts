// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {IERC1155, ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {ERC1155SinglePortal} from "contracts/portals/ERC1155SinglePortal.sol";
import {IERC1155SinglePortal} from "contracts/portals/IERC1155SinglePortal.sol";
import {IInputBox} from "contracts/inputs/IInputBox.sol";
import {IPortal} from "contracts/portals/IPortal.sol";
import {InputEncoding} from "contracts/common/InputEncoding.sol";

import {ERC165Test} from "../util/ERC165Test.sol";

contract NormalToken is ERC1155 {
    constructor(
        address tokenOwner,
        uint256 tokenId,
        uint256 supply
    ) ERC1155("NormalToken") {
        _mint(tokenOwner, tokenId, supply, "");
    }
}

contract ERC1155SinglePortalTest is ERC165Test {
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

    function getERC165Contract() public view override returns (IERC165) {
        return _portal;
    }

    function getSupportedInterfaces()
        public
        pure
        override
        returns (bytes4[] memory)
    {
        bytes4[] memory interfaceIds = new bytes4[](2);
        interfaceIds[0] = type(IERC1155SinglePortal).interfaceId;
        interfaceIds[1] = type(IPortal).interfaceId;
        return interfaceIds;
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
        bytes memory safeTransferFrom = _encodeSafeTransferFrom(
            tokenId,
            value,
            baseLayerData
        );

        vm.mockCall(address(_token), safeTransferFrom, abi.encode());
        vm.expectCall(address(_token), safeTransferFrom, 1);

        bytes memory payload = _encodePayload(
            tokenId,
            value,
            baseLayerData,
            execLayerData
        );

        bytes memory addInput = _encodeAddInput(payload);

        vm.mockCall(address(_inputBox), addInput, abi.encode(bytes32(0)));
        vm.expectCall(address(_inputBox), addInput, 1);

        vm.prank(_alice);
        _portal.depositSingleERC1155Token(
            _token,
            _appContract,
            tokenId,
            value,
            baseLayerData,
            execLayerData
        );
    }

    function testTokenReverts(
        uint256 tokenId,
        uint256 value,
        bytes calldata baseLayerData,
        bytes calldata execLayerData,
        bytes memory errorData
    ) public {
        bytes memory safeTransferFrom = _encodeSafeTransferFrom(
            tokenId,
            value,
            baseLayerData
        );

        vm.mockCall(address(_token), safeTransferFrom, abi.encode());
        vm.mockCallRevert(address(_token), safeTransferFrom, errorData);

        bytes memory payload = _encodePayload(
            tokenId,
            value,
            baseLayerData,
            execLayerData
        );

        bytes memory addInput = _encodeAddInput(payload);

        vm.mockCall(address(_inputBox), addInput, abi.encode(bytes32(0)));

        vm.expectRevert(errorData);

        vm.prank(_alice);
        _portal.depositSingleERC1155Token(
            _token,
            _appContract,
            tokenId,
            value,
            baseLayerData,
            execLayerData
        );
    }

    function testNormalToken(
        uint256 tokenId,
        uint256 supply,
        uint256 value,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) public {
        value = bound(value, 0, supply);
        _token = new NormalToken(_alice, tokenId, supply);

        vm.startPrank(_alice);

        // Allow the portal to withdraw tokens from Alice
        _token.setApprovalForAll(address(_portal), true);

        bytes memory payload = _encodePayload(
            tokenId,
            value,
            baseLayerData,
            execLayerData
        );

        bytes memory addInput = _encodeAddInput(payload);

        vm.mockCall(address(_inputBox), addInput, abi.encode(bytes32(0)));

        // balances before
        assertEq(_token.balanceOf(_alice, tokenId), supply);
        assertEq(_token.balanceOf(_appContract, tokenId), 0);
        assertEq(_token.balanceOf(address(_portal), tokenId), 0);

        vm.expectCall(address(_inputBox), addInput, 1);

        vm.expectEmit(true, true, true, true, address(_token));
        emit IERC1155.TransferSingle(
            address(_portal),
            _alice,
            _appContract,
            tokenId,
            value
        );

        _portal.depositSingleERC1155Token(
            _token,
            _appContract,
            tokenId,
            value,
            baseLayerData,
            execLayerData
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
        return
            InputEncoding.encodeSingleERC1155Deposit(
                _token,
                _alice,
                tokenId,
                value,
                baseLayerData,
                execLayerData
            );
    }

    function _encodeAddInput(
        bytes memory payload
    ) internal view returns (bytes memory) {
        return abi.encodeCall(IInputBox.addInput, (_appContract, payload));
    }

    function _encodeSafeTransferFrom(
        uint256 tokenId,
        uint256 value,
        bytes calldata baseLayerData
    ) internal view returns (bytes memory) {
        return
            abi.encodeCall(
                IERC1155.safeTransferFrom,
                (_alice, _appContract, tokenId, value, baseLayerData)
            );
    }
}
