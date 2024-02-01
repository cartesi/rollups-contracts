// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

import {IAuthorityFactory} from "./IAuthorityFactory.sol";
import {Authority} from "./Authority.sol";

/// @title Authority Factory
/// @notice Allows anyone to reliably deploy a new `Authority` contract.
contract AuthorityFactory is IAuthorityFactory {
    function newAuthority(
        address authorityOwner
    ) external override returns (Authority) {
        Authority authority = new Authority(authorityOwner);

        emit AuthorityCreated(authorityOwner, authority);

        return authority;
    }

    function newAuthority(
        address authorityOwner,
        bytes32 salt
    ) external override returns (Authority) {
        Authority authority = new Authority{salt: salt}(authorityOwner);

        emit AuthorityCreated(authorityOwner, authority);

        return authority;
    }

    function calculateAuthorityAddress(
        address authorityOwner,
        bytes32 salt
    ) external view override returns (address) {
        return
            Create2.computeAddress(
                salt,
                keccak256(
                    abi.encodePacked(
                        type(Authority).creationCode,
                        abi.encode(authorityOwner)
                    )
                )
            );
    }
}
