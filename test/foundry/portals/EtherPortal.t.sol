// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {EtherPortal} from "contracts/portals/EtherPortal.sol";
import {IEtherPortal} from "contracts/portals/IEtherPortal.sol";
import {IInputBox} from "contracts/inputs/IInputBox.sol";
import {IPortal} from "contracts/portals/IPortal.sol";
import {InputEncoding} from "contracts/common/InputEncoding.sol";

import {ERC165Test} from "../util/ERC165Test.sol";

contract EtherPortalTest is ERC165Test {
    address _alice;
    address _appContract;
    IInputBox _inputBox;
    IEtherPortal _portal;
    bytes4[] _interfaceIds;

    function setUp() public {
        _alice = vm.addr(1);
        _appContract = vm.addr(2);
        _inputBox = IInputBox(vm.addr(3));
        _portal = new EtherPortal(_inputBox);
        _interfaceIds.push(type(IEtherPortal).interfaceId);
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

    function testDeposit(uint256 value, bytes calldata data) public {
        value = _boundValue(value);

        bytes memory payload = _encodePayload(value, data);

        bytes memory addInput = _encodeAddInput(payload);

        vm.mockCall(address(_inputBox), addInput, abi.encode(bytes32(0)));

        vm.expectCall(_appContract, value, abi.encode(), 1);

        vm.expectCall(address(_inputBox), addInput, 1);

        uint256 balance = _appContract.balance;

        vm.deal(_alice, value);
        vm.prank(_alice);
        _portal.depositEther{value: value}(_appContract, data);

        assertEq(_appContract.balance, balance + value);
    }

    function testDepositReverts(
        uint256 value,
        bytes calldata data,
        bytes calldata errorData
    ) public {
        value = _boundValue(value);

        vm.mockCallRevert(_appContract, value, abi.encode(), errorData);

        bytes memory payload = _encodePayload(value, data);

        bytes memory addInput = _encodeAddInput(payload);

        vm.mockCall(address(_inputBox), addInput, abi.encode(bytes32(0)));

        vm.expectRevert(IEtherPortal.EtherTransferFailed.selector);

        vm.deal(_alice, value);
        vm.prank(_alice);
        _portal.depositEther{value: value}(_appContract, data);
    }

    function _encodePayload(
        uint256 value,
        bytes calldata data
    ) internal view returns (bytes memory) {
        return InputEncoding.encodeEtherDeposit(_alice, value, data);
    }

    function _encodeAddInput(
        bytes memory payload
    ) internal view returns (bytes memory) {
        return abi.encodeCall(IInputBox.addInput, (_appContract, payload));
    }

    function _boundValue(uint256 value) internal view returns (uint256) {
        return bound(value, 0, address(this).balance);
    }
}
