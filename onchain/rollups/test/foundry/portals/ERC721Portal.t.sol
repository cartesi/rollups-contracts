// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {ERC721Portal} from "contracts/portals/ERC721Portal.sol";
import {IERC721Portal} from "contracts/portals/IERC721Portal.sol";
import {IInputBox} from "contracts/inputs/IInputBox.sol";
import {IInputRelay} from "contracts/inputs/IInputRelay.sol";
import {InputEncoding} from "contracts/common/InputEncoding.sol";

import {Test} from "forge-std/Test.sol";

contract ERC721PortalTest is Test {
    address _alice;
    address _dapp;
    IERC721 _token;
    IInputBox _inputBox;
    IERC721Portal _portal;

    function setUp() public {
        _alice = vm.addr(1);
        _dapp = vm.addr(2);
        _token = IERC721(vm.addr(3));
        _inputBox = IInputBox(vm.addr(4));
        _portal = new ERC721Portal(_inputBox);
    }

    function testSupportsInterface(bytes4 interfaceId) public {
        assertTrue(_portal.supportsInterface(type(IERC721Portal).interfaceId));
        assertTrue(_portal.supportsInterface(type(IInputRelay).interfaceId));
        assertTrue(_portal.supportsInterface(type(IERC165).interfaceId));

        assertFalse(_portal.supportsInterface(bytes4(0xffffffff)));

        vm.assume(interfaceId != type(IERC721Portal).interfaceId);
        vm.assume(interfaceId != type(IInputRelay).interfaceId);
        vm.assume(interfaceId != type(IERC165).interfaceId);
        assertFalse(_portal.supportsInterface(interfaceId));
    }

    function testGetInputBox() public {
        assertEq(address(_portal.getInputBox()), address(_inputBox));
    }

    function testDeposit(
        uint256 tokenId,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) public {
        bytes memory safeTransferFrom = _encodeSafeTransferFrom(
            tokenId,
            baseLayerData
        );

        vm.mockCall(address(_token), safeTransferFrom, abi.encode());
        vm.expectCall(address(_token), safeTransferFrom, 1);

        bytes memory input = _encodeInput(
            tokenId,
            baseLayerData,
            execLayerData
        );

        bytes memory addInputCall = _encodeAddInput(input);

        vm.mockCall(address(_inputBox), addInputCall, abi.encode(bytes32(0)));
        vm.expectCall(address(_inputBox), addInputCall, 1);

        vm.prank(_alice);
        _portal.depositERC721Token(
            _token,
            _dapp,
            tokenId,
            baseLayerData,
            execLayerData
        );
    }

    function testTokenReverts(
        uint256 tokenId,
        bytes calldata baseLayerData,
        bytes calldata execLayerData,
        bytes memory errorData
    ) public {
        bytes memory safeTransferFrom = _encodeSafeTransferFrom(
            tokenId,
            baseLayerData
        );

        vm.mockCall(address(_token), safeTransferFrom, abi.encode());
        vm.mockCallRevert(address(_token), safeTransferFrom, errorData);

        bytes memory input = _encodeInput(
            tokenId,
            baseLayerData,
            execLayerData
        );

        bytes memory addInputCall = _encodeAddInput(input);

        vm.mockCall(address(_inputBox), addInputCall, abi.encode(bytes32(0)));

        vm.expectRevert(errorData);

        vm.prank(_alice);
        _portal.depositERC721Token(
            _token,
            _dapp,
            tokenId,
            baseLayerData,
            execLayerData
        );
    }

    function _encodeInput(
        uint256 tokenId,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) internal view returns (bytes memory) {
        return
            InputEncoding.encodeERC721Deposit(
                _token,
                _alice,
                tokenId,
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
        bytes calldata baseLayerData
    ) internal view returns (bytes memory) {
        return
            abi.encodeWithSignature(
                "safeTransferFrom(address,address,uint256,bytes)",
                _alice,
                _dapp,
                tokenId,
                baseLayerData
            );
    }
}
