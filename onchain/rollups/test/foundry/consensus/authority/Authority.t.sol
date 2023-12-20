// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Authority Test
pragma solidity ^0.8.8;

import {Vm} from "forge-std/Vm.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Authority} from "contracts/consensus/authority/Authority.sol";
import {IConsensus} from "contracts/consensus/IConsensus.sol";
import {InputRange} from "contracts/common/InputRange.sol";
import {LibInputRange} from "contracts/library/LibInputRange.sol";

import {TestBase} from "../../util/TestBase.sol";

contract AuthorityTest is TestBase {
    using LibInputRange for InputRange;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    event ClaimSubmission(
        address indexed submitter,
        address indexed app,
        InputRange inputRange,
        bytes32 epochHash
    );

    event ClaimAcceptance(
        address indexed app,
        InputRange inputRange,
        bytes32 epochHash
    );

    function testConstructor(address owner) public {
        vm.assume(owner != address(0));

        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(address(0), owner);

        vm.recordLogs();

        Authority authority = new Authority(owner);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(entries.length, 1, "number of events");

        assertEq(authority.owner(), owner, "authority owner");
    }

    function testRevertsOwnerAddressZero() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableInvalidOwner.selector,
                address(0)
            )
        );
        new Authority(address(0));
    }

    function testSubmitClaimRevertsCallerNotOwner(
        address owner,
        address notOwner,
        address app,
        InputRange calldata inputRange,
        bytes32 epochHash
    ) public {
        vm.assume(owner != address(0));
        vm.assume(owner != notOwner);

        Authority authority = new Authority(owner);

        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                notOwner
            )
        );

        vm.prank(notOwner);
        authority.submitClaim(app, inputRange, epochHash);
    }

    function testSubmitClaim(
        address owner,
        address app,
        InputRange calldata inputRange,
        bytes32 epochHash1,
        bytes32 epochHash2
    ) public {
        vm.assume(owner != address(0));

        Authority authority = new Authority(owner);

        // First claim

        expectClaimEvents(authority, owner, app, inputRange, epochHash1);

        vm.prank(owner);
        authority.submitClaim(app, inputRange, epochHash1);

        assertEq(authority.getEpochHash(app, inputRange), epochHash1);

        // Second claim

        expectClaimEvents(authority, owner, app, inputRange, epochHash2);

        vm.prank(owner);
        authority.submitClaim(app, inputRange, epochHash2);

        assertEq(authority.getEpochHash(app, inputRange), epochHash2);
    }

    function expectClaimEvents(
        Authority authority,
        address owner,
        address app,
        InputRange calldata inputRange,
        bytes32 epochHash
    ) internal {
        vm.expectEmit(true, true, false, true, address(authority));
        emit ClaimSubmission(owner, app, inputRange, epochHash);

        vm.expectEmit(true, false, false, true, address(authority));
        emit ClaimAcceptance(app, inputRange, epochHash);
    }
}
