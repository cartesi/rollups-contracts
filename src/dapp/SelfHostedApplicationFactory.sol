// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.30;

import {RollupsContract} from "../common/RollupsContract.sol";
import {WithdrawalConfig} from "../common/WithdrawalConfig.sol";
import {IOutputsMerkleRootValidator} from "../consensus/IOutputsMerkleRootValidator.sol";
import {IAuthority} from "../consensus/authority/IAuthority.sol";
import {IAuthorityFactory} from "../consensus/authority/IAuthorityFactory.sol";
import {IInputBox} from "../inputs/IInputBox.sol";
import {IApplication} from "./IApplication.sol";
import {IApplicationFactory} from "./IApplicationFactory.sol";
import {ISelfHostedApplicationFactory} from "./ISelfHostedApplicationFactory.sol";

/// @title Self-hosted Application Factory
/// @notice Allows anyone to reliably deploy a new IAuthority contract,
/// along with an IApplication contract already linked to it.
contract SelfHostedApplicationFactory is ISelfHostedApplicationFactory, RollupsContract {
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
        uint256 claimStagingPeriod,
        bytes32 templateHash,
        IInputBox inputBox,
        WithdrawalConfig calldata withdrawalConfig,
        bytes32 salt
    ) external returns (IApplication application, IAuthority authority) {
        authority = AUTHORITY_FACTORY.newAuthority(
                authorityOwner, epochLength, claimStagingPeriod, salt
            );

        application = APPLICATION_FACTORY.newApplication(
            authority, address(this), templateHash, inputBox, withdrawalConfig, salt
        );

        application.renounceOwnership();
    }

    function calculateAddresses(
        address authorityOwner,
        uint256 epochLength,
        uint256 claimStagingPeriod,
        bytes32 templateHash,
        IInputBox inputBox,
        WithdrawalConfig calldata withdrawalConfig,
        bytes32 salt
    ) external view returns (address application, address authority) {
        authority = AUTHORITY_FACTORY.calculateAuthorityAddress(
                authorityOwner, epochLength, claimStagingPeriod, salt
            );

        application = APPLICATION_FACTORY.calculateApplicationAddress(
            IOutputsMerkleRootValidator(authority),
            address(this),
            templateHash,
            inputBox,
            withdrawalConfig,
            salt
        );
    }
}
