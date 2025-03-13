// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {IOwnable} from "src/access/IOwnable.sol";

import {Ownable} from "@openzeppelin-contracts-5.2.0/access/Ownable.sol";

import {Test} from "forge-std-1.9.6/Test.sol";

abstract contract OwnableTest is Test {
    /// @notice Get ownable contract to be tested
    function _getOwnableContract() internal view virtual returns (IOwnable);

    function testRenounceOwnership(address caller, address randomOwner) external {
        vm.assume(caller != address(0));
        vm.assume(randomOwner != address(0));

        IOwnable ownable = _getOwnableContract();
        address owner = ownable.owner();

        vm.expectEmit(true, true, false, false);
        emit Ownable.OwnershipTransferred(owner, address(0));

        vm.startPrank(owner);
        ownable.renounceOwnership();
        vm.stopPrank();

        assertEq(ownable.owner(), address(0));

        vm.startPrank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller)
        );
        ownable.transferOwnership(randomOwner);
        vm.stopPrank();
    }

    function testUnauthorizedAccount(address caller, address randomOwner) external {
        vm.assume(randomOwner != address(0));

        IOwnable ownable = _getOwnableContract();
        address owner = ownable.owner();

        vm.assume(caller != owner);

        vm.startPrank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller)
        );
        ownable.transferOwnership(randomOwner);
        vm.stopPrank();
    }

    function testInvalidOwner() external {
        IOwnable ownable = _getOwnableContract();
        address owner = ownable.owner();

        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0))
        );
        ownable.transferOwnership(address(0));
        vm.stopPrank();
    }

    function testTransferOwnership(address newOwner, address caller, address randomOwner)
        external
    {
        vm.assume(newOwner != address(0));
        vm.assume(caller != newOwner);
        vm.assume(randomOwner != address(0));

        IOwnable ownable = _getOwnableContract();
        address owner = ownable.owner();

        vm.expectEmit(true, true, false, false);
        emit Ownable.OwnershipTransferred(owner, newOwner);

        vm.startPrank(owner);
        ownable.transferOwnership(newOwner);
        vm.stopPrank();

        assertEq(ownable.owner(), newOwner);

        vm.startPrank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller)
        );
        ownable.transferOwnership(randomOwner);
        vm.stopPrank();
    }
}
