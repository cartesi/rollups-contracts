// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Authority Factory Test
pragma solidity ^0.8.22;

import {Vm} from "forge-std/Vm.sol";
import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {AuthorityFactory} from
    "contracts/consensus/authority/AuthorityFactory.sol";
import {IAuthorityFactory} from
    "contracts/consensus/authority/IAuthorityFactory.sol";
import {IAuthority} from "contracts/consensus/authority/IAuthority.sol";

contract AuthorityFactoryTest is Test {
    AuthorityFactory _factory;

    function setUp() public {
        _factory = new AuthorityFactory();
    }

    function testRevertsOwnerAddressZero(uint256 epochLength, bytes32 salt)
        public
    {
        vm.assume(epochLength > 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableInvalidOwner.selector, address(0)
            )
        );
        _factory.newAuthority(address(0), epochLength);

        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableInvalidOwner.selector, address(0)
            )
        );
        _factory.newAuthority(address(0), epochLength, salt);
    }

    function testRevertsEpochLengthZero(address authorityOwner, bytes32 salt)
        public
    {
        vm.assume(authorityOwner != address(0));

        vm.expectRevert("epoch length must not be zero");
        _factory.newAuthority(authorityOwner, 0);

        vm.expectRevert("epoch length must not be zero");
        _factory.newAuthority(authorityOwner, 0, salt);
    }

    function testNewAuthority(address authorityOwner, uint256 epochLength)
        public
    {
        vm.assume(authorityOwner != address(0));
        vm.assume(epochLength > 0);

        vm.recordLogs();

        IAuthority authority =
            _factory.newAuthority(authorityOwner, epochLength);

        _testNewAuthorityAux(authorityOwner, epochLength, authority);
    }

    function testNewAuthorityDeterministic(
        address authorityOwner,
        uint256 epochLength,
        bytes32 salt
    ) public {
        vm.assume(authorityOwner != address(0));
        vm.assume(epochLength > 0);

        address precalculatedAddress = _factory.calculateAuthorityAddress(
            authorityOwner, epochLength, salt
        );

        vm.recordLogs();

        IAuthority authority =
            _factory.newAuthority(authorityOwner, epochLength, salt);

        _testNewAuthorityAux(authorityOwner, epochLength, authority);

        // Precalculated address must match actual address
        assertEq(precalculatedAddress, address(authority));

        precalculatedAddress = _factory.calculateAuthorityAddress(
            authorityOwner, epochLength, salt
        );

        // Precalculated address must STILL match actual address
        assertEq(precalculatedAddress, address(authority));

        // Cannot deploy an authority with the same salt twice
        vm.expectRevert();
        _factory.newAuthority(authorityOwner, epochLength, salt);
    }

    function _testNewAuthorityAux(
        address authorityOwner,
        uint256 epochLength,
        IAuthority authority
    ) internal {
        Vm.Log[] memory entries = vm.getRecordedLogs();

        uint256 numOfAuthorityCreated;

        for (uint256 i; i < entries.length; ++i) {
            Vm.Log memory entry = entries[i];

            if (
                entry.emitter == address(_factory)
                    && entry.topics[0]
                        == IAuthorityFactory.AuthorityCreated.selector
            ) {
                ++numOfAuthorityCreated;

                address authorityAddress = abi.decode(entry.data, (address));

                assertEq(address(authority), authorityAddress);
            }
        }

        assertEq(numOfAuthorityCreated, 1);
        assertEq(authority.owner(), authorityOwner);
        assertEq(authority.getEpochLength(), epochLength);
    }
}
