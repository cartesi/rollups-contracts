// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {IVersionGetter} from "../../common/IVersionGetter.sol";
import {IConsensusFactoryErrors} from "../IConsensusFactoryErrors.sol";
import {IAuthority} from "./IAuthority.sol";

/// @title Authority Factory interface
interface IAuthorityFactory is IVersionGetter, IConsensusFactoryErrors {
    // Events

    /// @notice A new authority was deployed.
    /// @param authority The authority
    /// @dev MUST be triggered on a successful call to `newAuthority`
    ///      or `newReservedAuthority`.
    event AuthorityCreated(IAuthority authority);

    // Permissionless functions

    /// @notice Deploy a new authority.
    /// @param authorityOwner The initial authority owner
    /// @param epochLength The epoch length
    /// @param claimStagingPeriod The claim staging period, in base-layer blocks (see `IConsensus`)
    /// @return The authority
    /// @dev On success, MUST emit an `AuthorityCreated` event.
    /// @dev Reverts if the authority owner address is zero.
    /// @dev Reverts if the epoch length is zero.
    function newAuthority(
        address authorityOwner,
        uint256 epochLength,
        uint256 claimStagingPeriod
    ) external returns (IAuthority);

    /// @notice Deploy a new authority deterministically.
    /// @param authorityOwner The initial authority owner
    /// @param epochLength The epoch length
    /// @param claimStagingPeriod The claim staging period, in base-layer blocks (see `IConsensus`)
    /// @param salt The salt used to deterministically generate the authority address
    /// @return The authority
    /// @dev On success, MUST emit an `AuthorityCreated` event.
    /// @dev Reverts if the authority owner address is zero.
    /// @dev Reverts if the epoch length is zero.
    /// @dev Reverts with empty error data if the address already contains code,
    ///      consuming 63/64 of the gas left during deployment.
    ///      Users can check the code size of `calculateAuthorityAddress` first.
    function newAuthority(
        address authorityOwner,
        uint256 epochLength,
        uint256 claimStagingPeriod,
        bytes32 salt
    ) external returns (IAuthority);

    /// @notice Calculate the address of an authority to be deployed deterministically.
    /// @param authorityOwner The initial authority owner
    /// @param epochLength The epoch length
    /// @param claimStagingPeriod The claim staging period, in base-layer blocks (see `IConsensus`)
    /// @param salt The salt used to deterministically generate the authority address
    /// @return The deterministic authority address
    /// @dev Beware that only the `newAuthority` function with the `salt` parameter
    ///      is able to deploy an authority at this address.
    /// @dev The address does not depend on the caller,
    ///      so anyone can deploy any given authority.
    ///      Factories that configure authorities after deploying them should
    ///      therefore not assume they have deployed an authority simply from
    ///      the fact that its pre-calculated address contains some code.
    ///      Such factories should use `newReservedAuthority` instead.
    function calculateAuthorityAddress(
        address authorityOwner,
        uint256 epochLength,
        uint256 claimStagingPeriod,
        bytes32 salt
    ) external view returns (address);

    /// @notice Deploy a new authority at an address reserved for the caller.
    /// @param authorityOwner The initial authority owner
    /// @param epochLength The epoch length
    /// @param claimStagingPeriod The claim staging period, in base-layer blocks (see `IConsensus`)
    /// @param salt The salt used, along with the caller, to generate the address
    /// @return The authority
    /// @dev On success, MUST emit an `AuthorityCreated` event.
    /// @dev Reverts if the authority owner address is zero.
    /// @dev Reverts if the epoch length is zero.
    /// @dev Reverts with empty error data if the address already contains code,
    ///      consuming 63/64 of the gas left during deployment.
    ///      Users can check the code size of `calculateReservedAuthorityAddress` first.
    function newReservedAuthority(
        address authorityOwner,
        uint256 epochLength,
        uint256 claimStagingPeriod,
        bytes32 salt
    ) external returns (IAuthority);

    /// @notice Calculate the address of an authority reserved for a given caller.
    /// @param authorityOwner The initial authority owner
    /// @param epochLength The epoch length
    /// @param claimStagingPeriod The claim staging period, in base-layer blocks (see `IConsensus`)
    /// @param salt The salt used, along with the caller, to generate the address
    /// @param caller The caller of `newReservedAuthority`
    /// @return The deterministic authority address
    /// @dev Only `newReservedAuthority`, called by `caller`, deploys at this address.
    function calculateReservedAuthorityAddress(
        address authorityOwner,
        uint256 epochLength,
        uint256 claimStagingPeriod,
        bytes32 salt,
        address caller
    ) external view returns (address);
}
