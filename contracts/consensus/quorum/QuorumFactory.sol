// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

import {IQuorumFactory} from "./IQuorumFactory.sol";
import {IQuorum} from "./IQuorum.sol";
import {Quorum} from "./Quorum.sol";

/// @title Quorum Factory
/// @notice Allows anyone to reliably deploy a new `IQuorum` contract.
contract QuorumFactory is IQuorumFactory {
    function newQuorum(
        address[] calldata validators,
        uint256 epochLength
    ) external override returns (IQuorum) {
        IQuorum quorum = new Quorum(validators, epochLength);

        emit QuorumCreated(quorum);

        return quorum;
    }

    function newQuorum(
        address[] calldata validators,
        uint256 epochLength,
        bytes32 salt
    ) external override returns (IQuorum) {
        IQuorum quorum = new Quorum{salt: salt}(validators, epochLength);

        emit QuorumCreated(quorum);

        return quorum;
    }

    function calculateQuorumAddress(
        address[] calldata validators,
        uint256 epochLength,
        bytes32 salt
    ) external view override returns (address) {
        return
            Create2.computeAddress(
                salt,
                keccak256(
                    abi.encodePacked(
                        type(Quorum).creationCode,
                        abi.encode(validators, epochLength)
                    )
                )
            );
    }
}
