// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Authority Test
pragma solidity ^0.8.22;

import {Vm} from "forge-std/Vm.sol";
import {Test} from "forge-std/Test.sol";

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Authority} from "src/consensus/authority/Authority.sol";
import {IAuthority} from "src/consensus/authority/IAuthority.sol";
import {IClaimSubmitter} from "src/consensus/IClaimSubmitter.sol";
import {IOwnable} from "src/access/IOwnable.sol";

import {ERC165Test} from "../../util/ERC165Test.sol";
import {LibTopic} from "../../util/LibTopic.sol";
import {OwnableTest} from "../../util/OwnableTest.sol";

contract AuthorityTest is Test, ERC165Test, OwnableTest {
    using LibTopic for address;

    IAuthority _authority;

    function setUp() external {
        _authority = new Authority(vm.addr(1), 1);
    }

    /// @inheritdoc ERC165Test
    function _getERC165Contract() internal view override returns (IERC165) {
        return _authority;
    }

    /// @inheritdoc ERC165Test
    function _getSupportedInterfaces()
        internal
        pure
        override
        returns (bytes4[] memory)
    {
        bytes4[] memory ifaces = new bytes4[](3);
        ifaces[0] = type(IERC165).interfaceId;
        ifaces[1] = type(IClaimSubmitter).interfaceId;
        ifaces[2] = type(IAuthority).interfaceId;
        return ifaces;
    }

    /// @inheritdoc OwnableTest
    function _getOwnableContract() internal view override returns (IOwnable) {
        return _authority;
    }

    function testConstructor(address owner, uint256 epochLength) public {
        vm.assume(owner != address(0));
        vm.assume(epochLength > 0);

        vm.recordLogs();

        IAuthority authority = new Authority(owner, epochLength);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        uint256 numOfOwnershipTransferred;

        for (uint256 i; i < entries.length; ++i) {
            Vm.Log memory entry = entries[i];

            if (
                entry.emitter == address(authority)
                    && entry.topics[0] == Ownable.OwnershipTransferred.selector
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
        assertEq(authority.getEpochLength(), epochLength);
    }

    function testRevertsOwnerAddressZero(uint256 epochLength) public {
        vm.assume(epochLength > 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableInvalidOwner.selector, address(0)
            )
        );
        new Authority(address(0), epochLength);
    }

    function testRevertsEpochLengthZero(address owner) public {
        vm.assume(owner != address(0));

        vm.expectRevert("epoch length must not be zero");
        new Authority(owner, 0);
    }

    function testSubmitClaimRevertsCallerNotOwner(
        address owner,
        address notOwner,
        uint256 epochLength,
        address appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 claim
    ) public {
        vm.assume(owner != address(0));
        vm.assume(owner != notOwner);
        vm.assume(epochLength > 0);

        IAuthority authority = new Authority(owner, epochLength);

        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector, notOwner
            )
        );

        vm.prank(notOwner);
        authority.submitClaim(appContract, lastProcessedBlockNumber, claim);
    }

    function testSubmitClaim(
        address owner,
        uint256 epochLength,
        address appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 claim
    ) public {
        vm.assume(owner != address(0));
        vm.assume(epochLength > 0);

        IAuthority authority = new Authority(owner, epochLength);

        _expectClaimEvents(
            authority, owner, appContract, lastProcessedBlockNumber, claim
        );

        vm.prank(owner);
        authority.submitClaim(appContract, lastProcessedBlockNumber, claim);

        assertTrue(authority.isOutputsMerkleRootValid(appContract, claim));
    }

    function testIsOutputsMerkleRootValid(
        address owner,
        uint256 epochLength,
        address appContract,
        bytes32 claim
    ) public {
        vm.assume(owner != address(0));
        vm.assume(epochLength > 0);

        IAuthority authority = new Authority(owner, epochLength);

        assertFalse(authority.isOutputsMerkleRootValid(appContract, claim));
    }

    function _expectClaimEvents(
        IAuthority authority,
        address owner,
        address appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 claim
    ) internal {
        vm.expectEmit(true, true, false, true, address(authority));
        emit IClaimSubmitter.ClaimSubmission(
            owner, appContract, lastProcessedBlockNumber, claim
        );

        vm.expectEmit(true, false, false, true, address(authority));
        emit IClaimSubmitter.ClaimAcceptance(
            appContract, lastProcessedBlockNumber, claim
        );
    }
}
