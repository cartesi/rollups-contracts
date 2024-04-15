// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC721, ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import {ERC721Portal} from "contracts/portals/ERC721Portal.sol";
import {IERC721Portal} from "contracts/portals/IERC721Portal.sol";
import {IInputBox} from "contracts/inputs/IInputBox.sol";
import {IPortal} from "contracts/portals/IPortal.sol";
import {InputEncoding} from "contracts/common/InputEncoding.sol";

import {ERC165Test} from "../util/ERC165Test.sol";

contract NormalToken is ERC721 {
    constructor(
        address tokenOwner,
        uint256 tokenId
    ) ERC721("NormalToken", "NORMAL") {
        _safeMint(tokenOwner, tokenId);
    }
}

contract ERC721PortalTest is ERC165Test {
    address _alice;
    address _appContract;
    IERC721 _token;
    IInputBox _inputBox;
    IERC721Portal _portal;
    bytes4[] _interfaceIds;

    function setUp() public {
        _alice = vm.addr(1);
        _appContract = vm.addr(2);
        _token = IERC721(vm.addr(3));
        _inputBox = IInputBox(vm.addr(4));
        _portal = new ERC721Portal(_inputBox);
        _interfaceIds.push(type(IERC721Portal).interfaceId);
        _interfaceIds.push(type(IPortal).interfaceId);
    }

    function getERC165Contract() public view override returns (IERC165) {
        return _portal;
    }

    function getSupportedInterfaces()
        public
        view
        override
        returns (bytes4[] memory)
    {
        return _interfaceIds;
    }

    function testGetInputBox() public view {
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

        bytes memory payload = _encodePayload(
            _token,
            tokenId,
            baseLayerData,
            execLayerData
        );

        bytes memory addInput = _encodeAddInput(payload);

        vm.mockCall(address(_inputBox), addInput, abi.encode(bytes32(0)));
        vm.expectCall(address(_inputBox), addInput, 1);

        vm.prank(_alice);
        _portal.depositERC721Token(
            _token,
            _appContract,
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

        bytes memory payload = _encodePayload(
            _token,
            tokenId,
            baseLayerData,
            execLayerData
        );

        bytes memory addInput = _encodeAddInput(payload);

        vm.mockCall(address(_inputBox), addInput, abi.encode(bytes32(0)));

        vm.expectRevert(errorData);

        vm.prank(_alice);
        _portal.depositERC721Token(
            _token,
            _appContract,
            tokenId,
            baseLayerData,
            execLayerData
        );
    }

    function testNormalToken(
        uint256 tokenId,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) public {
        NormalToken token = new NormalToken(_alice, tokenId);

        vm.startPrank(_alice);

        token.approve(address(_portal), tokenId);

        // token owner before
        assertEq(token.ownerOf(tokenId), _alice);

        bytes memory payload = _encodePayload(
            token,
            tokenId,
            baseLayerData,
            execLayerData
        );

        bytes memory addInput = _encodeAddInput(payload);

        vm.mockCall(address(_inputBox), addInput, abi.encode(bytes32(0)));

        vm.expectCall(address(_inputBox), addInput, 1);

        vm.expectEmit(true, true, true, false, address(token));
        emit IERC721.Transfer(_alice, _appContract, tokenId);

        _portal.depositERC721Token(
            token,
            _appContract,
            tokenId,
            baseLayerData,
            execLayerData
        );

        vm.stopPrank();

        // token owner after
        assertEq(token.ownerOf(tokenId), _appContract);
    }

    function _encodePayload(
        IERC721 token,
        uint256 tokenId,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) internal view returns (bytes memory) {
        return
            InputEncoding.encodeERC721Deposit(
                token,
                _alice,
                tokenId,
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
        bytes calldata baseLayerData
    ) internal view returns (bytes memory) {
        return
            abi.encodeWithSignature(
                "safeTransferFrom(address,address,uint256,bytes)",
                _alice,
                _appContract,
                tokenId,
                baseLayerData
            );
    }
}
