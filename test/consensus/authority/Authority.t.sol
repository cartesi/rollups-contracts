// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Authority Test
pragma solidity ^0.8.22;

import {Vm} from "forge-std/Vm.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Authority} from "contracts/consensus/authority/Authority.sol";
import {IAuthority} from "contracts/consensus/authority/IAuthority.sol";
import {IConsensus} from "contracts/consensus/IConsensus.sol";
import {IOwnable} from "contracts/access/IOwnable.sol";

import {TestBase} from "../../util/TestBase.sol";
import {LibTopic} from "../../util/LibTopic.sol";
import {OwnableTest} from "../../util/OwnableTest.sol";

contract AuthorityTest is TestBase, OwnableTest {
    using LibTopic for address;

    IAuthority _authority;

    uint256 constant EPOCH_LENGTH = 4 * 60 * 24 * 7;

    function setUp() external {
        _authority = new Authority(vm.addr(1), EPOCH_LENGTH);
    }

    function _getOwnableContract() internal view override returns (IOwnable) {
        return _authority;
    }

    function testConstructor(address owner, uint256 epochLength) public {
        vm.assume(owner != address(0));

        vm.recordLogs();

        IAuthority authority = new Authority(owner, epochLength);

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

    function testGetNumberOfSealedEpochs(address appContract) external view {
        assertEq(_authority.getNumberOfSealedEpochs(appContract), 0);
    }

    function testSubmitClaims(
        address appContract,
        bytes32[] calldata claims
    ) external {
        for (uint256 i; i < claims.length; ++i) {
            bytes32 claim = claims[i];
            assertEq(_authority.getNumberOfSealedEpochs(appContract), i);
            vm.roll(vm.getBlockNumber() + EPOCH_LENGTH);
            assertTrue(_authority.canSealEpoch(appContract));
            _authority.sealEpoch(appContract);
            assertEq(
                uint256(_authority.getEpochPhase(appContract, i)),
                uint256(IConsensus.Phase.WAITING_FOR_CLAIMS)
            );
            vm.expectEmit(true, true, true, true, address(_authority));
            emit IConsensus.ClaimSubmission(
                appContract,
                i,
                _authority.owner(),
                claim
            );
            vm.expectEmit(true, true, false, true, address(_authority));
            emit IConsensus.SettledEpoch(appContract, i, claim);
            vm.prank(_authority.owner());
            _authority.submitClaim(appContract, i, claim);
            assertFalse(_authority.canSealEpoch(appContract));
            assertEq(
                uint256(_authority.getEpochPhase(appContract, i)),
                uint256(IConsensus.Phase.SETTLED)
            );
            assertTrue(_authority.wasClaimSettled(appContract, claim));
        }
    }

    function testRevertsOwnerAddressZero(uint256 epochLength) public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableInvalidOwner.selector,
                address(0)
            )
        );
        new Authority(address(0), epochLength);
    }

    function testSubmitClaimRevertsCallerNotOwner(
        address owner,
        address notOwner,
        address appContract,
        bytes32 claim
    ) public {
        vm.assume(owner != address(0));
        vm.assume(owner != notOwner);

        IAuthority authority = new Authority(owner, EPOCH_LENGTH);

        uint256 epochIndex = 0;

        authority.sealEpoch(appContract);

        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                notOwner
            )
        );

        vm.prank(notOwner);
        authority.submitClaim(appContract, epochIndex, claim);
    }

    function testWasClaimSettled(
        address appContract,
        bytes32 claim
    ) external view {
        assertFalse(_authority.wasClaimSettled(appContract, claim));
    }

    function testGetDisputeResolutionModuleRevertsInvalidIndex(
        address appContract,
        uint256 epochIndex
    ) external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IConsensus.InvalidEpochIndex.selector,
                appContract,
                epochIndex
            )
        );
        _authority.getDisputeResolutionModule(appContract, epochIndex);
    }

    function testGetDisputeResolutionModuleRevertsInvalidPhase(
        address appContract
    ) external {
        uint256 epochIndex = 0;

        _authority.sealEpoch(appContract);

        vm.expectRevert(
            abi.encodeWithSelector(
                IConsensus.InvalidEpochPhase.selector,
                appContract,
                epochIndex
            )
        );
        _authority.getDisputeResolutionModule(appContract, epochIndex);
    }
}
