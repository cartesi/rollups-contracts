// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {EtherPortal} from "contracts/portals/EtherPortal.sol";
import {IEtherPortal} from "contracts/portals/IEtherPortal.sol";
import {IInputBox} from "contracts/inputs/IInputBox.sol";
import {IInputRelay} from "contracts/inputs/IInputRelay.sol";
import {InputEncoding} from "contracts/common/InputEncoding.sol";

import {Test} from "forge-std/Test.sol";

contract EtherPortalTest is Test {
    address _alice;
    address payable _app;
    IInputBox _inputBox;
    IEtherPortal _portal;

    function setUp() public {
        _alice = vm.addr(1);
        _app = payable(vm.addr(2));
        _inputBox = IInputBox(vm.addr(3));
        _portal = new EtherPortal(_inputBox);
    }

    function testSupportsInterface(bytes4 interfaceId) public {
        assertTrue(_portal.supportsInterface(type(IEtherPortal).interfaceId));
        assertTrue(_portal.supportsInterface(type(IInputRelay).interfaceId));
        assertTrue(_portal.supportsInterface(type(IERC165).interfaceId));

        assertFalse(_portal.supportsInterface(bytes4(0xffffffff)));

        vm.assume(interfaceId != type(IEtherPortal).interfaceId);
        vm.assume(interfaceId != type(IInputRelay).interfaceId);
        vm.assume(interfaceId != type(IERC165).interfaceId);
        assertFalse(_portal.supportsInterface(interfaceId));
    }

    function testGetInputBox() public {
        assertEq(address(_portal.getInputBox()), address(_inputBox));
    }

    function testDeposit(uint256 value, bytes calldata data) public {
        value = _boundValue(value);

        bytes memory input = _encodeInput(value, data);

        bytes memory addInput = _encodeAddInput(input);

        vm.mockCall(address(_inputBox), addInput, abi.encode(bytes32(0)));

        vm.expectCall(_app, value, abi.encode(), 1);

        vm.expectCall(address(_inputBox), addInput, 1);

        uint256 balance = _app.balance;

        vm.deal(_alice, value);
        vm.prank(_alice);
        _portal.depositEther{value: value}(_app, data);

        assertEq(_app.balance, balance + value);
    }

    function testDepositReverts(
        uint256 value,
        bytes calldata data,
        bytes calldata errorData
    ) public {
        value = _boundValue(value);

        vm.mockCallRevert(_app, value, abi.encode(), errorData);

        bytes memory input = _encodeInput(value, data);

        bytes memory addInput = _encodeAddInput(input);

        vm.mockCall(address(_inputBox), addInput, abi.encode(bytes32(0)));

        vm.expectRevert(IEtherPortal.EtherTransferFailed.selector);

        vm.deal(_alice, value);
        vm.prank(_alice);
        _portal.depositEther{value: value}(_app, data);
    }

    function _encodeInput(
        uint256 value,
        bytes calldata data
    ) internal view returns (bytes memory) {
        return InputEncoding.encodeEtherDeposit(_alice, value, data);
    }

    function _encodeAddInput(
        bytes memory input
    ) internal view returns (bytes memory) {
        return abi.encodeCall(IInputBox.addInput, (_app, input));
    }

    function _boundValue(uint256 value) internal view returns (uint256) {
        return bound(value, 0, address(this).balance);
    }
}
