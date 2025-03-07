// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

import {IAuthorityFactory} from "./IAuthorityFactory.sol";
import {Authority} from "./Authority.sol";
import {IAuthority} from "./IAuthority.sol";

/// @title Authority Factory
/// @notice Allows anyone to reliably deploy a new `IAuthority` contract.
contract AuthorityFactory is IAuthorityFactory {
    function newAuthority(address authorityOwner, uint256 epochLength)
        external
        override
        returns (IAuthority)
    {
        IAuthority authority = new Authority(authorityOwner, epochLength);

        emit AuthorityCreated(authority);

        return authority;
    }

    function newAuthority(
        address authorityOwner,
        uint256 epochLength,
        bytes32 salt
    ) external override returns (IAuthority) {
        IAuthority authority =
            new Authority{salt: salt}(authorityOwner, epochLength);

        emit AuthorityCreated(authority);

        return authority;
    }

    function calculateAuthorityAddress(
        address authorityOwner,
        uint256 epochLength,
        bytes32 salt
    ) external view override returns (address) {
        return Create2.computeAddress(
            salt,
            keccak256(
                abi.encodePacked(
                    type(Authority).creationCode,
                    abi.encode(authorityOwner, epochLength)
                )
            )
        );
    }
}
