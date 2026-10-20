// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.30;

import {IVersionGetter} from "../common/IVersionGetter.sol";
import {WithdrawalConfig} from "../common/WithdrawalConfig.sol";
import {IConsensusFactoryErrors} from "../consensus/IConsensusFactoryErrors.sol";
import {IAuthority} from "../consensus/authority/IAuthority.sol";
import {IAuthorityFactory} from "../consensus/authority/IAuthorityFactory.sol";
import {IInputBox} from "../inputs/IInputBox.sol";
import {IApplication} from "./IApplication.sol";
import {IApplicationFactory} from "./IApplicationFactory.sol";
import {IApplicationFactoryErrors} from "./IApplicationFactoryErrors.sol";

/// @title Self-hosted Application Factory interface
interface ISelfHostedApplicationFactory is
    IVersionGetter,
    IConsensusFactoryErrors,
    IApplicationFactoryErrors
{
    /// @notice Get the factory used to deploy `IAuthority` contracts
    /// @return The authority factory
    function getAuthorityFactory() external view returns (IAuthorityFactory);

    /// @notice Get the factory used to deploy `IApplication` contracts
    /// @return The application factory
    function getApplicationFactory() external view returns (IApplicationFactory);

    /// @notice Deploy new application and authority contracts deterministically.
    /// @param authorityOwner The initial authority owner
    /// @param epochLength The epoch length
    /// @param claimStagingPeriod The claim staging period
    /// @param templateHash The initial machine state hash
    /// @param inputBox The input box contract
    /// @param withdrawalConfig The withdrawal configuration
    /// @param salt The salt used to deterministically generate the addresses
    /// @return The application contract
    /// @return The authority contract
    /// @dev Reverts if the authority owner address is zero.
    /// @dev Reverts if the epoch length is zero.
    /// @dev Reverts if either address already contains code. Since the underlying
    ///      factories are permissionless and their addresses do not depend on
    ///      the caller, anyone can deploy either contract beforehand.
    ///      In that case, deploy the missing contract (if any) directly through
    ///      the authority or application factory, with the same arguments,
    ///      or pick a different, random salt.
    function deployContracts(
        address authorityOwner,
        uint256 epochLength,
        uint256 claimStagingPeriod,
        bytes32 templateHash,
        IInputBox inputBox,
        WithdrawalConfig calldata withdrawalConfig,
        bytes32 salt
    ) external returns (IApplication, IAuthority);

    /// @notice Calculate the addresses of the application and authority contracts
    /// to be deployed deterministically.
    /// @param authorityOwner The initial authority owner
    /// @param epochLength The epoch length
    /// @param claimStagingPeriod The claim staging period
    /// @param templateHash The initial machine state hash
    /// @param inputBox The input box contract
    /// @param withdrawalConfig The withdrawal configuration
    /// @param salt The salt used to deterministically generate the addresses
    /// @return The application address
    /// @return The authority address
    /// @dev The contracts at these addresses may have been deployed by anyone,
    ///      through this factory or directly through the underlying ones.
    ///      Either way, if both addresses hold code, the contracts are sound.
    /// @dev Do not transfer assets to the application address before deployment:
    ///      deposit through the portals afterwards, so that the application
    ///      is informed through an input.
    function calculateAddresses(
        address authorityOwner,
        uint256 epochLength,
        uint256 claimStagingPeriod,
        bytes32 templateHash,
        IInputBox inputBox,
        WithdrawalConfig calldata withdrawalConfig,
        bytes32 salt
    ) external view returns (address, address);
}
