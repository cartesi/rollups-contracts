// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Test} from "forge-std-1.9.6/src/Test.sol";
import {Vm} from "forge-std-1.9.6/src/Vm.sol";

import {App} from "src/app/interfaces/App.sol";
import {IEtherPortal} from "src/portals/IEtherPortal.sol";
import {Inbox} from "src/app/interfaces/Inbox.sol";
import {InputEncoding} from "src/common/InputEncoding.sol";

import {LibCannon} from "test/util/LibCannon.sol";

contract EtherPortalTest is Test {
    using LibCannon for Vm;

    address _alice;
    App _appContract;
    IEtherPortal _portal;

    function setUp() public {
        _alice = vm.addr(1);
        _appContract = App(vm.addr(2));
        _portal = IEtherPortal(vm.getAddress("EtherPortal"));
    }

    function testDeposit(uint256 value, bytes calldata data) public {
        value = _boundValue(value);

        bytes memory payload = _encodePayload(value, data);

        bytes memory addInput = _encodeAddInput(payload);

        vm.mockCall(address(_appContract), addInput, abi.encode(bytes32(0)));

        vm.expectCall(address(_appContract), addInput, 1);

        uint256 balance = address(_appContract).balance;

        vm.deal(_alice, value);
        vm.prank(_alice);
        _portal.depositEther{value: value}(_appContract, data);

        assertEq(address(_appContract).balance, balance + value);
    }

    function testDepositReverts(
        uint256 value,
        bytes calldata data,
        bytes calldata errorData
    ) public {
        value = _boundValue(value);

        vm.mockCallRevert(address(_appContract), value, abi.encode(), errorData);

        bytes memory payload = _encodePayload(value, data);

        bytes memory addInput = _encodeAddInput(payload);

        vm.mockCall(address(_appContract), addInput, abi.encode(bytes32(0)));

        vm.expectRevert(IEtherPortal.EtherTransferFailed.selector);

        vm.deal(_alice, value);
        vm.prank(_alice);
        _portal.depositEther{value: value}(_appContract, data);
    }

    function _encodePayload(uint256 value, bytes calldata data)
        internal
        view
        returns (bytes memory)
    {
        return InputEncoding.encodeEtherDeposit(_alice, value, data);
    }

    function _encodeAddInput(bytes memory payload)
        internal
        pure
        returns (bytes memory input)
    {
        return abi.encodeCall(Inbox.addInput, (payload));
    }

    function _boundValue(uint256 value) internal view returns (uint256) {
        return bound(value, 0, address(this).balance);
    }
}
