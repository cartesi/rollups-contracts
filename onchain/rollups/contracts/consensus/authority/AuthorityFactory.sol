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
        address _authorityOwner
    ) external override returns (Authority) {
        Authority authority = new Authority(_authorityOwner);

        emit AuthorityCreated(_authorityOwner, authority);

        return authority;
    }

    function newAuthority(
        address _authorityOwner,
        bytes32 _salt
    ) external override returns (Authority) {
        Authority authority = new Authority{salt: _salt}(_authorityOwner);

        emit AuthorityCreated(_authorityOwner, authority);

        return authority;
    }

    function calculateAuthorityAddress(
        address _authorityOwner,
        bytes32 _salt
    ) external view override returns (address) {
        return
            Create2.computeAddress(
                _salt,
                keccak256(
                    abi.encodePacked(
                        type(Authority).creationCode,
                        abi.encode(_authorityOwner)
                    )
                )
            );
    }
}
