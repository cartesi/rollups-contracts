// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {IERC1155, ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {ERC1155BatchPortal} from "contracts/portals/ERC1155BatchPortal.sol";
import {IERC1155BatchPortal} from "contracts/portals/IERC1155BatchPortal.sol";
import {IInputBox} from "contracts/inputs/IInputBox.sol";
import {IInputRelay} from "contracts/inputs/IInputRelay.sol";
import {InputEncoding} from "contracts/common/InputEncoding.sol";

import {Test} from "forge-std/Test.sol";

contract NormalToken is ERC1155 {
    constructor(
        address tokenOwner,
        uint256[] memory tokenIds,
        uint256[] memory supplies
    ) ERC1155("BatchToken") {
        _mintBatch(tokenOwner, tokenIds, supplies, "");
    }
}

contract TokenHolder is ERC1155Holder {}

contract ERC1155BatchPortalTest is Test {
    address _alice;
    address _app;
    IERC1155 _token;
    IInputBox _inputBox;
    IERC1155BatchPortal _portal;

    function setUp() public {
        _alice = vm.addr(1);
        _app = vm.addr(2);
        _token = IERC1155(vm.addr(3));
        _inputBox = IInputBox(vm.addr(4));
        _portal = new ERC1155BatchPortal(_inputBox);
    }

    function testSupportsInterface(bytes4 interfaceId) public {
        assertTrue(
            _portal.supportsInterface(type(IERC1155BatchPortal).interfaceId)
        );
        assertTrue(_portal.supportsInterface(type(IInputRelay).interfaceId));
        assertTrue(_portal.supportsInterface(type(IERC165).interfaceId));

        assertFalse(_portal.supportsInterface(bytes4(0xffffffff)));

        vm.assume(interfaceId != type(IERC1155BatchPortal).interfaceId);
        vm.assume(interfaceId != type(IInputRelay).interfaceId);
        vm.assume(interfaceId != type(IERC165).interfaceId);
        assertFalse(_portal.supportsInterface(interfaceId));
    }

    function testGetInputBox() public {
        assertEq(address(_portal.getInputBox()), address(_inputBox));
    }

    function testDeposit(
        uint256[] calldata tokenIds,
        uint256[] calldata values,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) public {
        bytes memory safeBatchTransferFrom = _encodeSafeBatchTransferFrom(
            tokenIds,
            values,
            baseLayerData
        );

        vm.mockCall(address(_token), safeBatchTransferFrom, abi.encode());
        vm.expectCall(address(_token), safeBatchTransferFrom, 1);

        bytes memory input = _encodeInput(
            tokenIds,
            values,
            baseLayerData,
            execLayerData
        );

        bytes memory addInputCall = _encodeAddInput(input);

        vm.mockCall(address(_inputBox), addInputCall, abi.encode(bytes32(0)));
        vm.expectCall(address(_inputBox), addInputCall, 1);

        vm.prank(_alice);
        _portal.depositBatchERC1155Token(
            _token,
            _app,
            tokenIds,
            values,
            baseLayerData,
            execLayerData
        );
    }

    function testTokenReverts(
        uint256[] calldata tokenIds,
        uint256[] calldata values,
        bytes calldata baseLayerData,
        bytes calldata execLayerData,
        bytes memory errorData
    ) public {
        bytes memory safeBatchTransferFrom = _encodeSafeBatchTransferFrom(
            tokenIds,
            values,
            baseLayerData
        );

        vm.mockCall(address(_token), safeBatchTransferFrom, abi.encode());
        vm.mockCallRevert(address(_token), safeBatchTransferFrom, errorData);

        bytes memory input = _encodeInput(
            tokenIds,
            values,
            baseLayerData,
            execLayerData
        );

        bytes memory addInputCall = _encodeAddInput(input);

        vm.mockCall(address(_inputBox), addInputCall, abi.encode(bytes32(0)));

        vm.expectRevert(errorData);

        vm.prank(_alice);
        _portal.depositBatchERC1155Token(
            _token,
            _app,
            tokenIds,
            values,
            baseLayerData,
            execLayerData
        );
    }

    function testNormalToken(
        uint256[] calldata supplies,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) public {
        // construct arrays of tokenIds and values
        uint256 numOfTokenIds = supplies.length;
        vm.assume(numOfTokenIds > 1);
        uint256[] memory tokenIds = new uint256[](numOfTokenIds);
        uint256[] memory values = new uint256[](numOfTokenIds);
        for (uint256 i; i < numOfTokenIds; ++i) {
            tokenIds[i] = i;
            values[i] = bound(i, 0, supplies[i]);
        }

        _token = new NormalToken(_alice, tokenIds, supplies);
        _app = address(new TokenHolder());

        vm.startPrank(_alice);

        // Allow the portal to withdraw tokens from Alice
        _token.setApprovalForAll(address(_portal), true);

        vm.mockCall(
            address(_inputBox),
            abi.encodeWithSelector(IInputBox.addInput.selector),
            abi.encode(bytes32(0))
        );

        // balances before
        for (uint256 i; i < numOfTokenIds; ++i) {
            assertEq(_token.balanceOf(_alice, tokenIds[i]), supplies[i]);
            assertEq(_token.balanceOf(_app, tokenIds[i]), 0);
            assertEq(_token.balanceOf(address(_portal), tokenIds[i]), 0);
        }

        vm.expectEmit(true, true, true, true);
        emit IERC1155.TransferBatch(
            address(_portal),
            _alice,
            _app,
            tokenIds,
            values
        );

        _portal.depositBatchERC1155Token(
            _token,
            _app,
            tokenIds,
            values,
            baseLayerData,
            execLayerData
        );
        vm.stopPrank();

        // balances after
        for (uint256 i; i < numOfTokenIds; ++i) {
            assertEq(
                _token.balanceOf(_alice, tokenIds[i]),
                supplies[i] - values[i]
            );
            assertEq(_token.balanceOf(_app, tokenIds[i]), values[i]);
            assertEq(_token.balanceOf(address(_portal), tokenIds[i]), 0);
        }
    }

    function _encodeInput(
        uint256[] calldata tokenIds,
        uint256[] calldata values,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) internal view returns (bytes memory) {
        return
            InputEncoding.encodeBatchERC1155Deposit(
                _token,
                _alice,
                tokenIds,
                values,
                baseLayerData,
                execLayerData
            );
    }

    function _encodeAddInput(
        bytes memory input
    ) internal view returns (bytes memory) {
        return abi.encodeCall(IInputBox.addInput, (_app, input));
    }

    function _encodeSafeBatchTransferFrom(
        uint256[] calldata tokenIds,
        uint256[] calldata values,
        bytes calldata baseLayerData
    ) internal view returns (bytes memory) {
        return
            abi.encodeCall(
                IERC1155.safeBatchTransferFrom,
                (_alice, _app, tokenIds, values, baseLayerData)
            );
    }
}
