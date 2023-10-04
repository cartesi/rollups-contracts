// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

import {IQuorumFactory} from "./IQuorumFactory.sol";
import {Quorum} from "./Quorum.sol";
import {IHistory} from "../../history/IHistory.sol";

/// @title Quorum factory
/// @notice Allows anyone to reliably deploy a new `Quorum` contract.
contract QuorumFactory is IQuorumFactory {
    function newQuorum(
        address[] calldata _quorumValidators,
        uint256[] calldata _shares,
        IHistory _history
    ) external override returns (Quorum) {
        Quorum quorum = new Quorum(_quorumValidators,_shares,_history);

        emit QuorumCreated(_quorumValidators, quorum);

        return quorum;
    }

    function newQuorum(
        address[] calldata _quorumValidators,
        uint256[] calldata _shares,
        IHistory _history,
        bytes32 _salt
    ) external override returns (Quorum) {
        Quorum quorum = new Quorum{salt: _salt}(_quorumValidators, _shares, _history);

        emit QuorumCreated(_quorumValidators, quorum);

        return quorum;
    }

    function calculateQuorumAddress(
        address[] calldata _quorumValidators,
        uint256[] calldata _shares,
        IHistory _history,
        bytes32 _salt
    ) external view override returns (address) {
        return
            Create2.computeAddress(
                _salt,
                keccak256(
                    abi.encodePacked(
                        type(Quorum).creationCode,
                        abi.encode(_quorumValidators, _shares, _history)
                    )
                )
            );
    }
}