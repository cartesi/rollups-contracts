// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Authority Test
pragma solidity ^0.8.22;

import {Vm} from "forge-std/Vm.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Authority} from "contracts/consensus/authority/Authority.sol";
import {IConsensus} from "contracts/consensus/IConsensus.sol";
import {InputRange} from "contracts/common/InputRange.sol";
import {LibInputRange} from "contracts/library/LibInputRange.sol";

import {TestBase} from "../../util/TestBase.sol";
import {LibTopic} from "../../util/LibTopic.sol";

contract AuthorityTest is TestBase {
    using LibInputRange for InputRange;
    using LibTopic for address;

    function testConstructor(address owner) public {
        vm.assume(owner != address(0));

        vm.recordLogs();

        Authority authority = new Authority(owner);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        uint256 numOfOwnershipTransferred;

        for (uint256 i; i < entries.length; ++i) {
            Vm.Log memory entry = entries[i];

            if (
                entry.emitter == address(authority) &&
                entry.topics[0] == Ownable.OwnershipTransferred.selector
            ) {
                ++numOfOwnershipTransferred;

                if (numOfOwnershipTransferred == 1) {
                    assertEq(entry.topics[1], address(0).asTopic());
                    assertEq(entry.topics[2], owner.asTopic());
                }
            }
        }

        assertEq(numOfOwnershipTransferred, 1);
        assertEq(authority.owner(), owner);
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
        bytes32[2] calldata epochHashes
    ) public {
        vm.assume(owner != address(0));

        Authority authority = new Authority(owner);

        // First claim

        _expectClaimEvents(authority, owner, app, inputRange, epochHashes[0]);

        vm.prank(owner);
        authority.submitClaim(app, inputRange, epochHashes[0]);

        assertEq(authority.getEpochHash(app, inputRange), epochHashes[0]);

        // Second claim

        _expectClaimEvents(authority, owner, app, inputRange, epochHashes[1]);

        vm.prank(owner);
        authority.submitClaim(app, inputRange, epochHashes[1]);

        assertEq(authority.getEpochHash(app, inputRange), epochHashes[1]);
    }

    function testGetEpochHash(
        address owner,
        address app,
        InputRange calldata inputRange
    ) public {
        vm.assume(owner != address(0));

        Authority authority = new Authority(owner);

        assertEq(authority.getEpochHash(app, inputRange), bytes32(0));
    }

    function _expectClaimEvents(
        Authority authority,
        address owner,
        address app,
        InputRange calldata inputRange,
        bytes32 epochHash
    ) internal {
        vm.expectEmit(true, true, false, true, address(authority));
        emit IConsensus.ClaimSubmission(owner, app, inputRange, epochHash);

        vm.expectEmit(true, false, false, true, address(authority));
        emit IConsensus.ClaimAcceptance(app, inputRange, epochHash);
    }
}
