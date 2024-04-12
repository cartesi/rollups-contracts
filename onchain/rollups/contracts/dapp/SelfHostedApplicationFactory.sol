// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.13;

import {Authority} from "../consensus/authority/Authority.sol";
import {ICartesiDAppFactory} from "./ICartesiDAppFactory.sol";
import {CartesiDApp} from "./CartesiDApp.sol";
import {History} from "../history/History.sol";
import {IAuthorityHistoryPairFactory} from "../consensus/authority/IAuthorityHistoryPairFactory.sol";
import {IConsensus} from "../consensus/IConsensus.sol";
import {ISelfHostedApplicationFactory} from "./ISelfHostedApplicationFactory.sol";

/// @title Self-hosted Application Factory
/// @notice Allows anyone to reliably deploy a new Authority-History pair,
/// along with a CartesiDApp contract already linked to it.
contract SelfHostedApplicationFactory is ISelfHostedApplicationFactory {
    IAuthorityHistoryPairFactory immutable authorityHistoryPairFactory;
    ICartesiDAppFactory immutable applicationFactory;

    /// @param _authorityHistoryPairFactory The authority-history pair factory
    /// @param _applicationFactory The application factory
    constructor(
        IAuthorityHistoryPairFactory _authorityHistoryPairFactory,
        ICartesiDAppFactory _applicationFactory
    ) {
        authorityHistoryPairFactory = _authorityHistoryPairFactory;
        applicationFactory = _applicationFactory;
    }

    function getAuthorityHistoryPairFactory()
        external
        view
        override
        returns (IAuthorityHistoryPairFactory)
    {
        return authorityHistoryPairFactory;
    }

    function getApplicationFactory()
        external
        view
        override
        returns (ICartesiDAppFactory)
    {
        return applicationFactory;
    }

    function deployContracts(
        address _authorityOwner,
        address _dappOwner,
        bytes32 _templateHash,
        bytes32 _salt
    )
        external
        returns (
            CartesiDApp application_,
            Authority authority_,
            History history_
        )
    {
        (authority_, history_) = authorityHistoryPairFactory
            .newAuthorityHistoryPair(_authorityOwner, _salt);

        application_ = applicationFactory.newApplication(
            authority_,
            _dappOwner,
            _templateHash,
            _salt
        );
    }

    function calculateAddresses(
        address _authorityOwner,
        address _dappOwner,
        bytes32 _templateHash,
        bytes32 _salt
    )
        external
        view
        returns (address application_, address authority_, address history_)
    {
        (authority_, history_) = authorityHistoryPairFactory
            .calculateAuthorityHistoryAddressPair(_authorityOwner, _salt);

        application_ = applicationFactory.calculateApplicationAddress(
            IConsensus(authority_),
            _dappOwner,
            _templateHash,
            _salt
        );
    }
}
