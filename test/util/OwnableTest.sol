// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Test} from "forge-std-1.9.6/src/Test.sol";
import {Vm} from "forge-std-1.9.6/src/Vm.sol";

import {Ownable} from "@openzeppelin-contracts-5.2.0/access/Ownable.sol";

import {IOwnable} from "src/access/IOwnable.sol";

import {LibAddressArray} from "./LibAddressArray.sol";

abstract contract OwnableTest is Test {
    using LibAddressArray for Vm;

    function _testRenounceOwnership(IOwnable ownable) internal {
        address owner = ownable.owner();
        address newOwner = _randomAddressDifferentFromZero();
        address caller = _randomAddressDifferentFromZero();

        vm.expectEmit(true, true, true, true, address(ownable), 1);
        emit Ownable.OwnershipTransferred(owner, address(0));

        vm.prank(owner);
        ownable.renounceOwnership();

        assertEq(ownable.owner(), address(0));

        vm.expectRevert(_encodeOwnableUnauthorizedAccount(caller));
        vm.prank(caller);
        ownable.transferOwnership(newOwner);
    }

    function _testUnauthorizedAccount(IOwnable ownable) internal {
        address owner = ownable.owner();
        address newOwner = _randomAddressDifferentFromZero();
        address caller = _randomAddressDifferentFromZeroAnd(owner);

        vm.expectRevert(_encodeOwnableUnauthorizedAccount(caller));
        vm.prank(caller);
        ownable.transferOwnership(newOwner);
    }

    function _testInvalidOwner(IOwnable ownable) internal {
        address owner = ownable.owner();

        vm.expectRevert(_encodeOwnableInvalidOwner());
        vm.prank(owner);
        ownable.transferOwnership(address(0));
    }

    function _testTransferOwnership(IOwnable ownable) internal {
        address owner = ownable.owner();
        address newOwner = _randomAddressDifferentFromZero();
        address anotherNewOwner = _randomAddressDifferentFromZero();
        address caller = _randomAddressDifferentFromZeroAnd(newOwner);

        vm.expectEmit(true, true, false, false);
        emit Ownable.OwnershipTransferred(owner, newOwner);

        vm.prank(owner);
        ownable.transferOwnership(newOwner);

        assertEq(ownable.owner(), newOwner);

        vm.expectRevert(_encodeOwnableUnauthorizedAccount(caller));
        vm.prank(caller);
        ownable.transferOwnership(anotherNewOwner);
    }

    function _randomAddressDifferentFromZero() internal returns (address) {
        address[] memory disallowList = new address[](1);
        disallowList[0] = address(0);
        return vm.randomAddressNotIn(disallowList);
    }

    function _randomAddressDifferentFromZeroAnd(address addr) internal returns (address) {
        address[] memory disallowList = new address[](2);
        disallowList[0] = address(0);
        disallowList[1] = addr;
        return vm.randomAddressNotIn(disallowList);
    }

    function _encodeOwnableInvalidOwner() internal pure returns (bytes memory) {
        return abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0));
    }

    function _encodeOwnableUnauthorizedAccount(address caller)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller);
    }
}
