// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IConsensus} from "./IConsensus.sol";

/// @notice Stores accepted claims for several applications.
/// @dev This contract was designed to be inherited by implementations of the `IConsensus` interface
/// that only need a simple mechanism of storage and retrieval of accepted claims.
abstract contract AbstractConsensus is IConsensus {
    /// @notice Indexes accepted claims by application contract address.
    mapping(address => mapping(bytes32 => bool)) private _acceptedClaims;

    /// @inheritdoc IConsensus
    function wasClaimAccepted(
        address appContract,
        bytes32 claim
    ) public view override returns (bool) {
        return _acceptedClaims[appContract][claim];
    }

    /// @notice Accept a claim.
    /// @param appContract The application contract address
    /// @param lastProcessedBlockNumber The number of the last processed block
    /// @param claim The output Merkle root hash
    /// @dev Emits a `ClaimAcceptance` event.
    function _acceptClaim(
        address appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 claim
    ) internal {
        _acceptedClaims[appContract][claim] = true;
        emit ClaimAcceptance(appContract, lastProcessedBlockNumber, claim);
    }
}
