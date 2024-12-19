// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.8;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IAuthority} from "../consensus/authority/IAuthority.sol";
import {IAuthorityFactory} from "../consensus/authority/IAuthorityFactory.sol";
import {IApplication} from "./IApplication.sol";
import {IApplicationFactory} from "./IApplicationFactory.sol";

/// @title Self-hosted Application Factory interface
interface ISelfHostedApplicationFactory {
    /// @notice Get the factory used to deploy `IAuthority` contracts
    /// @return The authority factory
    function getAuthorityFactory() external view returns (IAuthorityFactory);

    /// @notice Get the factory used to deploy `IApplication` contracts
    /// @return The application factory
    function getApplicationFactory()
        external
        view
        returns (IApplicationFactory);

    /// @notice Deploy new application and authority contracts deterministically.
    /// @param authorityOwner The initial authority owner
    /// @param epochLength The epoch length
    /// @param appOwner The initial application owner
    /// @param templateHash The initial machine state hash
    /// @param dataAvailability The data availability solution
    /// @param salt The salt used to deterministically generate the addresses
    /// @return The application contract
    /// @return The authority contract
    /// @dev Reverts if the authority owner address is zero.
    /// @dev Reverts if the application owner address is zero.
    /// @dev Reverts if the epoch length is zero.
    function deployContracts(
        address authorityOwner,
        uint256 epochLength,
        address appOwner,
        bytes32 templateHash,
        IERC165 dataAvailability,
        bytes32 salt
    ) external returns (IApplication, IAuthority);

    /// @notice Calculate the addresses of the application and authority contracts
    /// to be deployed deterministically.
    /// @param authorityOwner The initial authority owner
    /// @param epochLength The epoch length
    /// @param appOwner The initial application owner
    /// @param templateHash The initial machine state hash
    /// @param dataAvailability The data availability solution
    /// @param salt The salt used to deterministically generate the addresses
    /// @return The application address
    /// @return The authority address
    function calculateAddresses(
        address authorityOwner,
        uint256 epochLength,
        address appOwner,
        bytes32 templateHash,
        IERC165 dataAvailability,
        bytes32 salt
    ) external view returns (address, address);
}
