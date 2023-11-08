// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IQuorumHistoryPairFactory} from "./IQuorumHistoryPairFactory.sol";
import {Quorum} from "./Quorum.sol";
import {IQuorumFactory} from "./IQuorumFactory.sol";
import {History} from "../../history/History.sol";
import {IHistoryFactory} from "../../history/IHistoryFactory.sol";

/// @title Quorum-History Pair Factory
/// @notice Allows anyone to reliably deploy a new Quorum-History pair.
contract QuorumHistoryPairFactory is IQuorumHistoryPairFactory {
    IQuorumFactory immutable quorumFactory;
    IHistoryFactory immutable historyFactory;

    /// @notice Constructs the factory.
    /// @param _quorumFactory The `Quorum` factory
    /// @param _historyFactory The `History` factory
    constructor(
        IQuorumFactory _quorumFactory,
        IHistoryFactory _historyFactory
    ) {
        quorumFactory = _quorumFactory;
        historyFactory = _historyFactory;

        emit QuorumHistoryPairFactoryCreated(_quorumFactory, _historyFactory);
    }

    function getQuorumFactory()
        external
        view
        override
        returns (IQuorumFactory)
    {
        return quorumFactory;
    }

    function getHistoryFactory()
        external
        view
        override
        returns (IHistoryFactory)
    {
        return historyFactory;
    }

    function newQuorumHistoryPair(
        address[] calldata _validators,
        uint256[] calldata _shares
    ) external override returns (Quorum quorum_, History history_) {
        history_ = historyFactory.newHistory(address(this));
        quorum_ = quorumFactory.newQuorum(_validators, _shares, history_);

        history_.transferOwnership(address(quorum_));
    }

    function newQuorumHistoryPair(
        address[] calldata _validators,
        uint256[] calldata _shares,
        bytes32 _salt
    ) external override returns (Quorum quorum_, History history_) {
        history_ = historyFactory.newHistory(
            address(this),
            calculateCompoundSalt(_validators, _shares, _salt)
        );
        quorum_ = quorumFactory.newQuorum(
            _validators,
            _shares,
            history_,
            _salt
        );

        history_.transferOwnership(address(quorum_));
    }

    function calculateQuorumHistoryAddressPair(
        address[] calldata _validators,
        uint256[] calldata _shares,
        bytes32 _salt
    )
        external
        view
        override
        returns (address quorumAddress_, address historyAddress_)
    {
        historyAddress_ = historyFactory.calculateHistoryAddress(
            address(this),
            calculateCompoundSalt(_validators, _shares, _salt)
        );
        quorumAddress_ = quorumFactory.calculateQuorumAddress(
            _validators,
            _shares,
            historyAddress_,
            _salt
        );
    }

    /// @notice Calculate the compound salt.
    /// @param _validators the list of validators
    /// @param _shares the list of shares
    /// @param _salt salt
    /// @return compound salt
    /// @dev The purpose of calculating a compound salt is to
    /// prevent attackers front-running the creation of a History
    /// occupying the to-be-deployed address, but with different validators/shares.
    function calculateCompoundSalt(
        address[] calldata _validators,
        uint256[] calldata _shares,
        bytes32 _salt
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_validators, _shares, _salt));
    }
}
