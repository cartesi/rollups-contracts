// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IAuthority} from "./IAuthority.sol";

/// @title Authority Factory interface
interface IAuthorityFactory {
    // Events

    /// @notice A new authority was deployed.
    /// @param authority The authority
    /// @dev MUST be triggered on a successful call to `newAuthority`.
    event AuthorityCreated(IAuthority authority);

    // Permissionless functions

    /// @notice Deploy a new authority.
    /// @param authorityOwner The initial authority owner
    /// @param epochLength The epoch length
    /// @return The authority
    /// @dev On success, MUST emit an `AuthorityCreated` event.
    /// @dev Reverts if the authority owner address is zero.
    /// @dev Reverts if the epoch length is zero.
    function newAuthority(address authorityOwner, uint256 epochLength)
        external
        returns (IAuthority);

    /// @notice Deploy a new authority deterministically.
    /// @param authorityOwner The initial authority owner
    /// @param epochLength The epoch length
    /// @param salt The salt used to deterministically generate the authority address
    /// @return The authority
    /// @dev On success, MUST emit an `AuthorityCreated` event.
    /// @dev Reverts if the authority owner address is zero.
    /// @dev Reverts if the epoch length is zero.
    function newAuthority(
        address authorityOwner,
        uint256 epochLength,
        bytes32 salt
    ) external returns (IAuthority);

    /// @notice Calculate the address of an authority to be deployed deterministically.
    /// @param authorityOwner The initial authority owner
    /// @param epochLength The epoch length
    /// @param salt The salt used to deterministically generate the authority address
    /// @return The deterministic authority address
    /// @dev Beware that only the `newAuthority` function with the `salt` parameter
    ///      is able to deterministically deploy an authority.
    function calculateAuthorityAddress(
        address authorityOwner,
        uint256 epochLength,
        bytes32 salt
    ) external view returns (address);
}
