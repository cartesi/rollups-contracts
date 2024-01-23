// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {Authority} from "./Authority.sol";

/// @title Authority Factory interface
interface IAuthorityFactory {
    // Events

    /// @notice A new authority was deployed.
    /// @param authorityOwner The initial authority owner
    /// @param authority The authority
    /// @dev MUST be triggered on a successful call to `newAuthority`.
    event AuthorityCreated(address authorityOwner, Authority authority);

    // Permissionless functions

    /// @notice Deploy a new authority.
    /// @param authorityOwner The initial authority owner
    /// @return The authority
    /// @dev On success, MUST emit an `AuthorityCreated` event.
    function newAuthority(address authorityOwner) external returns (Authority);

    /// @notice Deploy a new authority deterministically.
    /// @param authorityOwner The initial authority owner
    /// @param salt The salt used to deterministically generate the authority address
    /// @return The authority
    /// @dev On success, MUST emit an `AuthorityCreated` event.
    function newAuthority(
        address authorityOwner,
        bytes32 salt
    ) external returns (Authority);

    /// @notice Calculate the address of an authority to be deployed deterministically.
    /// @param authorityOwner The initial authority owner
    /// @param salt The salt used to deterministically generate the authority address
    /// @return The deterministic authority address
    /// @dev Beware that only the `newAuthority` function with the `salt` parameter
    ///      is able to deterministically deploy an authority.
    function calculateAuthorityAddress(
        address authorityOwner,
        bytes32 salt
    ) external view returns (address);
}
