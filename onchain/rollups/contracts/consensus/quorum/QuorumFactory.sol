// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

import {IQuorumFactory} from "./IQuorumFactory.sol";
import {Quorum} from "./Quorum.sol";

/// @title Quorum Factory
/// @notice Allows anyone to reliably deploy a new `Quorum` contract.
contract QuorumFactory is IQuorumFactory {
    function newQuorum(
        address[] calldata validators
    ) external override returns (Quorum) {
        Quorum quorum = new Quorum(validators);

        emit QuorumCreated(quorum);

        return quorum;
    }

    function newQuorum(
        address[] calldata validators,
        bytes32 salt
    ) external override returns (Quorum) {
        Quorum quorum = new Quorum{salt: salt}(validators);

        emit QuorumCreated(quorum);

        return quorum;
    }

    function calculateQuorumAddress(
        address[] calldata validators,
        bytes32 salt
    ) external view override returns (address) {
        return
            Create2.computeAddress(
                salt,
                keccak256(
                    abi.encodePacked(
                        type(Quorum).creationCode,
                        abi.encode(validators)
                    )
                )
            );
    }
}
