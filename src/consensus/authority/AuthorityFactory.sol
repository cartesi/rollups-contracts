// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {Create2} from "@openzeppelin-contracts-5.2.0/utils/Create2.sol";

import {RollupsContract} from "../../common/RollupsContract.sol";
import {Authority} from "./Authority.sol";
import {IAuthority} from "./IAuthority.sol";
import {IAuthorityFactory} from "./IAuthorityFactory.sol";

/// @title Authority Factory
/// @notice Allows anyone to reliably deploy a new `IAuthority` contract.
contract AuthorityFactory is IAuthorityFactory, RollupsContract {
    function newAuthority(
        address authorityOwner,
        uint256 epochLength,
        uint256 claimStagingPeriod
    ) external override returns (IAuthority authority) {
        authority = new Authority(authorityOwner, epochLength, claimStagingPeriod);

        emit AuthorityCreated(authority);
    }

    function newAuthority(
        address authorityOwner,
        uint256 epochLength,
        uint256 claimStagingPeriod,
        bytes32 salt
    ) external override returns (IAuthority authority) {
        authority = new Authority{salt: salt}(
            authorityOwner, epochLength, claimStagingPeriod
        );

        emit AuthorityCreated(authority);
    }

    function calculateAuthorityAddress(
        address authorityOwner,
        uint256 epochLength,
        uint256 claimStagingPeriod,
        bytes32 salt
    ) external view override returns (address) {
        return Create2.computeAddress(
            salt,
            keccak256(
                abi.encodePacked(
                    type(Authority).creationCode,
                    abi.encode(authorityOwner, epochLength, claimStagingPeriod)
                )
            )
        );
    }
}
