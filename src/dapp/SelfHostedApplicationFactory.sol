// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.8;

import {IOutputsMerkleRootValidator} from "../consensus/IOutputsMerkleRootValidator.sol";
import {IAuthority} from "../consensus/authority/IAuthority.sol";
import {IAuthorityFactory} from "../consensus/authority/IAuthorityFactory.sol";
import {IApplication} from "./IApplication.sol";
import {IApplicationFactory} from "./IApplicationFactory.sol";
import {ISelfHostedApplicationFactory} from "./ISelfHostedApplicationFactory.sol";

/// @title Self-hosted Application Factory
/// @notice Allows anyone to reliably deploy a new IAuthority contract,
/// along with an IApplication contract already linked to it.
contract SelfHostedApplicationFactory is ISelfHostedApplicationFactory {
    IAuthorityFactory immutable AUTHORITY_FACTORY;
    IApplicationFactory immutable APPLICATION_FACTORY;

    /// @param authorityFactory The authority factory
    /// @param applicationFactory The application factory
    constructor(
        IAuthorityFactory authorityFactory,
        IApplicationFactory applicationFactory
    ) {
        AUTHORITY_FACTORY = authorityFactory;
        APPLICATION_FACTORY = applicationFactory;
    }

    function getAuthorityFactory() external view override returns (IAuthorityFactory) {
        return AUTHORITY_FACTORY;
    }

    function getApplicationFactory()
        external
        view
        override
        returns (IApplicationFactory)
    {
        return APPLICATION_FACTORY;
    }

    function deployContracts(
        address authorityOwner,
        uint256 epochLength,
        address appOwner,
        bytes32 templateHash,
        bytes calldata dataAvailability,
        bytes32 salt
    ) external returns (IApplication application, IAuthority authority) {
        authority = AUTHORITY_FACTORY.newAuthority(authorityOwner, epochLength, salt);

        application = APPLICATION_FACTORY.newApplication(
            authority, appOwner, templateHash, dataAvailability, salt
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
        authority = AUTHORITY_FACTORY.calculateAuthorityAddress(
                authorityOwner, epochLength, salt
            );

        application = APPLICATION_FACTORY.calculateApplicationAddress(
            IOutputsMerkleRootValidator(authority),
            appOwner,
            templateHash,
            dataAvailability,
            salt
        );
    }
}
