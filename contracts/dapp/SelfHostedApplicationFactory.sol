// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.8;

import {IConsensus} from "../consensus/IConsensus.sol";
import {Authority} from "../consensus/authority/Authority.sol";
import {IAuthorityFactory} from "../consensus/authority/IAuthorityFactory.sol";
import {Application} from "./Application.sol";
import {IApplicationFactory} from "./IApplicationFactory.sol";
import {ISelfHostedApplicationFactory} from "./ISelfHostedApplicationFactory.sol";
import {IInputBox} from "../inputs/IInputBox.sol";
import {IPortal} from "../portals/IPortal.sol";

/// @title Self-hosted Application Factory
/// @notice Allows anyone to reliably deploy a new Authority contract,
/// along with an Application contract already linked to it.
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
        IInputBox inputBox,
        IPortal[] memory portals,
        address appOwner,
        bytes32 templateHash,
        bytes32 salt
    ) external returns (Application application, Authority authority) {
        authority = _authorityFactory.newAuthority(authorityOwner, salt);

        application = _applicationFactory.newApplication(
            authority,
            inputBox,
            portals,
            appOwner,
            templateHash,
            salt
        );
    }

    function calculateAddresses(
        address authorityOwner,
        IInputBox inputBox,
        IPortal[] memory portals,
        address appOwner,
        bytes32 templateHash,
        bytes32 salt
    ) external view returns (address application, address authority) {
        authority = _authorityFactory.calculateAuthorityAddress(
            authorityOwner,
            salt
        );

        application = _applicationFactory.calculateApplicationAddress(
            IConsensus(authority),
            inputBox,
            portals,
            appOwner,
            templateHash,
            salt
        );
    }
}
