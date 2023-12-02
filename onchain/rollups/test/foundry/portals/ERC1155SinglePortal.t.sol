// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {ERC1155SinglePortal} from "contracts/portals/ERC1155SinglePortal.sol";
import {IERC1155SinglePortal} from "contracts/portals/IERC1155SinglePortal.sol";
import {IInputBox} from "contracts/inputs/IInputBox.sol";
import {IInputRelay} from "contracts/inputs/IInputRelay.sol";
import {InputEncoding} from "contracts/common/InputEncoding.sol";

import {Test} from "forge-std/Test.sol";

contract ERC1155SinglePortalTest is Test {
    address _alice;
    address _dapp;
    IERC1155 _token;
    IInputBox _inputBox;
    IERC1155SinglePortal _portal;

    function setUp() public {
        _alice = vm.addr(1);
        _dapp = vm.addr(2);
        _token = IERC1155(vm.addr(3));
        _inputBox = IInputBox(vm.addr(4));
        _portal = new ERC1155SinglePortal(_inputBox);
    }

    function testSupportsInterface(bytes4 interfaceId) public {
        assertTrue(
            _portal.supportsInterface(type(IERC1155SinglePortal).interfaceId)
        );
        assertTrue(_portal.supportsInterface(type(IInputRelay).interfaceId));
        assertTrue(_portal.supportsInterface(type(IERC165).interfaceId));

        assertFalse(_portal.supportsInterface(bytes4(0xffffffff)));

        vm.assume(interfaceId != type(IERC1155SinglePortal).interfaceId);
        vm.assume(interfaceId != type(IInputRelay).interfaceId);
        vm.assume(interfaceId != type(IERC165).interfaceId);
        assertFalse(_portal.supportsInterface(interfaceId));
    }

    function testGetInputBox() public {
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

        bytes memory input = _encodeInput(
            tokenId,
            value,
            baseLayerData,
            execLayerData
        );

        bytes memory addInputCall = _encodeAddInput(input);

        vm.mockCall(address(_inputBox), addInputCall, abi.encode(bytes32(0)));
        vm.expectCall(address(_inputBox), addInputCall, 1);

        vm.prank(_alice);
        _portal.depositSingleERC1155Token(
            _token,
            _dapp,
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

        bytes memory input = _encodeInput(
            tokenId,
            value,
            baseLayerData,
            execLayerData
        );

        bytes memory addInputCall = _encodeAddInput(input);

        vm.mockCall(address(_inputBox), addInputCall, abi.encode(bytes32(0)));

        vm.expectRevert(errorData);

        vm.prank(_alice);
        _portal.depositSingleERC1155Token(
            _token,
            _dapp,
            tokenId,
            value,
            baseLayerData,
            execLayerData
        );
    }

    function _encodeInput(
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
        bytes memory input
    ) internal view returns (bytes memory) {
        return abi.encodeCall(IInputBox.addInput, (_dapp, input));
    }

    function _encodeSafeTransferFrom(
        uint256 tokenId,
        uint256 value,
        bytes calldata baseLayerData
    ) internal view returns (bytes memory) {
        return
            abi.encodeCall(
                IERC1155.safeTransferFrom,
                (_alice, _dapp, tokenId, value, baseLayerData)
            );
    }
}
