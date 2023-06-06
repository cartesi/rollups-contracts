// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IAuthorityHistoryPairFactory} from "./IAuthorityHistoryPairFactory.sol";
import {Authority} from "./Authority.sol";
import {IAuthorityFactory} from "./IAuthorityFactory.sol";
import {History} from "../../history/History.sol";
import {IHistoryFactory} from "../../history/IHistoryFactory.sol";

/// @title Authority-History Pair Factory
/// @notice Allows anyone to reliably deploy a new Authority-History pair.
contract AuthorityHistoryPairFactory is IAuthorityHistoryPairFactory {
    IAuthorityFactory immutable authorityFactory;
    IHistoryFactory immutable historyFactory;

    /// @notice Constructs the factory.
    /// @param _authorityFactory The `Authority` factory
    /// @param _historyFactory The `History` factory
    constructor(
        IAuthorityFactory _authorityFactory,
        IHistoryFactory _historyFactory
    ) {
        authorityFactory = _authorityFactory;
        historyFactory = _historyFactory;

        emit AuthorityHistoryPairFactoryCreated(
            _authorityFactory,
            _historyFactory
        );
    }

    function getAuthorityFactory()
        external
        view
        override
        returns (IAuthorityFactory)
    {
        return authorityFactory;
    }

    function getHistoryFactory()
        external
        view
        override
        returns (IHistoryFactory)
    {
        return historyFactory;
    }

    function newAuthorityHistoryPair(
        address _authorityOwner
    ) external override returns (Authority authority_, History history_) {
        authority_ = authorityFactory.newAuthority(address(this));
        history_ = historyFactory.newHistory(address(authority_));

        authority_.setHistory(history_);
        authority_.transferOwnership(_authorityOwner);
    }

    function newAuthorityHistoryPair(
        address _authorityOwner,
        bytes32 _salt
    ) external override returns (Authority authority_, History history_) {
        _salt = calculateCompoundSalt(_authorityOwner, _salt);

        authority_ = authorityFactory.newAuthority(address(this), _salt);
        history_ = historyFactory.newHistory(address(authority_), _salt);

        authority_.setHistory(history_);
        authority_.transferOwnership(_authorityOwner);
    }

    function calculateAuthorityHistoryAddressPair(
        address _authorityOwner,
        bytes32 _salt
    )
        external
        view
        override
        returns (address authorityAddress_, address historyAddress_)
    {
        _salt = calculateCompoundSalt(_authorityOwner, _salt);

        authorityAddress_ = authorityFactory.calculateAuthorityAddress(
            address(this),
            _salt
        );

        historyAddress_ = historyFactory.calculateHistoryAddress(
            authorityAddress_,
            _salt
        );
    }

    function calculateCompoundSalt(
        address _authorityOwner,
        bytes32 _salt
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_authorityOwner, _salt));
    }
}
