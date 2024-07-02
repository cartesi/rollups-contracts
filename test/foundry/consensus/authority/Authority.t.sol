// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Authority Test
pragma solidity ^0.8.22;

import {Vm} from "forge-std/Vm.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Authority} from "contracts/consensus/authority/Authority.sol";
import {IConsensus} from "contracts/consensus/IConsensus.sol";

import {TestBase} from "../../util/TestBase.sol";
import {LibTopic} from "../../util/LibTopic.sol";

contract AuthorityTest is TestBase {
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
        address appContract,
        bytes32 claim
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
        authority.submitClaim(appContract, claim);
    }

    function testSubmitClaim(
        address owner,
        address appContract,
        bytes32 claim
    ) public {
        vm.assume(owner != address(0));

        Authority authority = new Authority(owner);

        _expectClaimEvents(authority, owner, appContract, claim);

        vm.prank(owner);
        authority.submitClaim(appContract, claim);

        assertTrue(authority.wasClaimAccepted(appContract, claim));
    }

    function testWasClaimAccepted(
        address owner,
        address appContract,
        bytes32 claim
    ) public {
        vm.assume(owner != address(0));

        Authority authority = new Authority(owner);

        assertFalse(authority.wasClaimAccepted(appContract, claim));
    }

    function _expectClaimEvents(
        Authority authority,
        address owner,
        address appContract,
        bytes32 claim
    ) internal {
        vm.expectEmit(true, true, false, true, address(authority));
        emit IConsensus.ClaimSubmission(owner, appContract, claim);

        vm.expectEmit(true, false, false, true, address(authority));
        emit IConsensus.ClaimAcceptance(appContract, claim);
    }
}
