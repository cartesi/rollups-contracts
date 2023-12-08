// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ERC20Portal} from "contracts/portals/ERC20Portal.sol";
import {IERC20Portal} from "contracts/portals/IERC20Portal.sol";
import {IInputBox} from "contracts/inputs/IInputBox.sol";
import {IInputRelay} from "contracts/inputs/IInputRelay.sol";
import {InputEncoding} from "contracts/common/InputEncoding.sol";

import {ERC165Test} from "../util/ERC165Test.sol";

contract ERC20PortalTest is ERC165Test {
    address _alice;
    address _dapp;
    IInputBox _inputBox;
    IERC20 _token;
    IERC20Portal _portal;

    function setUp() public {
        _alice = vm.addr(1);
        _dapp = vm.addr(2);
        _inputBox = IInputBox(vm.addr(3));
        _token = IERC20(vm.addr(4));
        _portal = new ERC20Portal(_inputBox);
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
        interfaceIds[0] = type(IERC20Portal).interfaceId;
        interfaceIds[1] = type(IInputRelay).interfaceId;
        return interfaceIds;
    }

    function testGetInputBox() public {
        assertEq(address(_portal.getInputBox()), address(_inputBox));
    }

    function testEmptyCode(uint256 amount, bytes calldata data) public {
        bytes memory input = _encodeInput(amount, data);

        bytes memory addInput = _encodeAddInput(input);

        vm.mockCall(address(_inputBox), addInput, abi.encode(bytes32(0)));

        vm.expectRevert(
            abi.encodeWithSelector(
                Address.AddressEmptyCode.selector,
                address(_token)
            )
        );

        vm.prank(_alice);
        _portal.depositERC20Tokens(_token, _dapp, amount, data);
    }

    function testTokenReturnsTrue(uint256 amount, bytes calldata data) public {
        _testTokenReturns(amount, data, abi.encode(true));
    }

    function testTokenReturnsNothing(
        uint256 amount,
        bytes calldata data
    ) public {
        _testTokenReturns(amount, data, abi.encode());
    }

    function testTokenReturnsFalse(uint256 amount, bytes calldata data) public {
        bytes memory transferFrom = _encodeTransferFrom(amount);

        vm.mockCall(address(_token), transferFrom, abi.encode(false));

        bytes memory input = _encodeInput(amount, data);

        bytes memory addInput = _encodeAddInput(input);

        vm.mockCall(address(_inputBox), addInput, abi.encode(bytes32(0)));

        vm.expectRevert(
            abi.encodeWithSelector(
                SafeERC20.SafeERC20FailedOperation.selector,
                address(_token)
            )
        );

        vm.prank(_alice);
        _portal.depositERC20Tokens(_token, _dapp, amount, data);
    }

    function testTokenReverts(
        uint256 amount,
        bytes calldata data,
        bytes memory errorData
    ) public {
        bytes memory transferFrom = _encodeTransferFrom(amount);

        vm.mockCallRevert(address(_token), transferFrom, errorData);

        bytes memory input = _encodeInput(amount, data);

        bytes memory addInput = _encodeAddInput(input);

        vm.mockCall(address(_inputBox), addInput, abi.encode(bytes32(0)));

        if (errorData.length > 0) {
            vm.expectRevert(errorData);
        } else {
            vm.expectRevert(Address.FailedInnerCall.selector);
        }

        vm.prank(_alice);
        _portal.depositERC20Tokens(_token, _dapp, amount, data);
    }

    function _encodeInput(
        uint256 amount,
        bytes calldata data
    ) internal view returns (bytes memory) {
        return InputEncoding.encodeERC20Deposit(_token, _alice, amount, data);
    }

    function _encodeTransferFrom(
        uint256 amount
    ) internal view returns (bytes memory) {
        return abi.encodeCall(IERC20.transferFrom, (_alice, _dapp, amount));
    }

    function _encodeAddInput(
        bytes memory _input
    ) internal view returns (bytes memory) {
        return abi.encodeCall(IInputBox.addInput, (_dapp, _input));
    }

    function _testTokenReturns(
        uint256 amount,
        bytes calldata data,
        bytes memory returnData
    ) internal {
        bytes memory transferFrom = _encodeTransferFrom(amount);

        vm.mockCall(address(_token), transferFrom, returnData);

        bytes memory input = _encodeInput(amount, data);

        bytes memory addInput = _encodeAddInput(input);

        vm.mockCall(address(_inputBox), addInput, abi.encode(bytes32(0)));

        vm.expectCall(address(_token), transferFrom, 1);

        vm.expectCall(address(_inputBox), addInput, 1);

        vm.prank(_alice);
        _portal.depositERC20Tokens(_token, _dapp, amount, data);
    }
}
