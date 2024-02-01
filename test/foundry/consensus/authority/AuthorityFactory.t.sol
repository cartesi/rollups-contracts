// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Authority Factory Test
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {AuthorityFactory, IAuthorityFactory} from "contracts/consensus/authority/AuthorityFactory.sol";
import {Authority} from "contracts/consensus/authority/Authority.sol";
import {Vm} from "forge-std/Vm.sol";

contract AuthorityFactoryTest is Test {
    AuthorityFactory _factory;

    struct AuthorityCreatedEventData {
        address authorityOwner;
        Authority authority;
    }

    function setUp() public {
        _factory = new AuthorityFactory();
    }

    function testNewAuthority(address authorityOwner) public {
        vm.assume(authorityOwner != address(0));

        vm.recordLogs();

        Authority authority = _factory.newAuthority(authorityOwner);

        _testNewAuthorityAux(authorityOwner, authority);
    }

    function testNewAuthorityDeterministic(
        address authorityOwner,
        bytes32 salt
    ) public {
        vm.assume(authorityOwner != address(0));

        address precalculatedAddress = _factory.calculateAuthorityAddress(
            authorityOwner,
            salt
        );

        vm.recordLogs();

        Authority authority = _factory.newAuthority(authorityOwner, salt);

        _testNewAuthorityAux(authorityOwner, authority);

        // Precalculated address must match actual address
        assertEq(precalculatedAddress, address(authority));

        precalculatedAddress = _factory.calculateAuthorityAddress(
            authorityOwner,
            salt
        );

        // Precalculated address must STILL match actual address
        assertEq(precalculatedAddress, address(authority));

        // Cannot deploy an authority with the same salt twice
        vm.expectRevert();
        _factory.newAuthority(authorityOwner, salt);
    }

    function _testNewAuthorityAux(
        address authorityOwner,
        Authority authority
    ) internal {
        Vm.Log[] memory entries = vm.getRecordedLogs();

        uint256 numOfAuthorityCreated;

        for (uint256 i; i < entries.length; ++i) {
            Vm.Log memory entry = entries[i];

            if (
                entry.emitter == address(_factory) &&
                entry.topics[0] == IAuthorityFactory.AuthorityCreated.selector
            ) {
                ++numOfAuthorityCreated;

                AuthorityCreatedEventData memory eventData;

                eventData = abi.decode(entry.data, (AuthorityCreatedEventData));

                assertEq(authorityOwner, eventData.authorityOwner);
                assertEq(address(authority), address(eventData.authority));
            }
        }

        assertEq(numOfAuthorityCreated, 1);

        // call to check authority's owner
        assertEq(authority.owner(), authorityOwner);
    }
}
