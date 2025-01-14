// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.8;

import {IConsensus} from "../consensus/IConsensus.sol";
import {IAuthority} from "../consensus/authority/IAuthority.sol";
import {IAuthorityFactory} from "../consensus/authority/IAuthorityFactory.sol";
import {IApplication} from "./IApplication.sol";
import {IApplicationFactory} from "./IApplicationFactory.sol";
import {ISelfHostedApplicationFactory} from "./ISelfHostedApplicationFactory.sol";

/// @title Self-hosted Application Factory
/// @notice Allows anyone to reliably deploy a new IAuthority contract,
/// along with an IApplication contract already linked to it.
contract SelfHostedApplicationFactory is ISelfHostedApplicationFactory {
    IAuthorityFactory immutable _authorityFactory;
    IApplicationFactory immutable _applicationFactory;

    /// @param authorityFactory The authority factory
    /// @param applicationFactory The application factory
    constructor(
        IAuthorityFactory authorityFactory,
        IApplicationFactory applicationFactory
    ) {
        _authorityFactory = authorityFactory;
        _applicationFactory = applicationFactory;
    }

    function getAuthorityFactory()
        external
        view
        override
        returns (IAuthorityFactory)
    {
        return _authorityFactory;
    }

    function getApplicationFactory()
        external
        view
        override
        returns (IApplicationFactory)
    {
        return _applicationFactory;
    }

    function deployContracts(
        address authorityOwner,
        uint256 epochLength,
        address appOwner,
        bytes32 templateHash,
        bytes calldata dataAvailability,
        bytes32 salt
    ) external returns (IApplication application, IAuthority authority) {
        authority = _authorityFactory.newAuthority(
            authorityOwner,
            epochLength,
            salt
        );

        application = _applicationFactory.newApplication(
            authority,
            appOwner,
            templateHash,
            dataAvailability,
            salt
        );
    }

    function calculateAddresses(
        address authorityOwner,
        uint256 epochLength,
        address appOwner,
        bytes32 templateHash,
        bytes calldata dataAvailability,
        bytes32 salt
    ) external view returns (address application, address authority) {
        authority = _authorityFactory.calculateAuthorityAddress(
            authorityOwner,
            epochLength,
            salt
        );

        application = _applicationFactory.calculateApplicationAddress(
            IConsensus(authority),
            appOwner,
            templateHash,
            dataAvailability,
            salt
        );
    }
}
