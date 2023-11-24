// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IConsensus} from "./IConsensus.sol";
import {InputRange} from "../common/InputRange.sol";
import {LibInputRange} from "../library/LibInputRange.sol";

/// @notice Stores epoch hashes for several DApps and input ranges.
/// @dev This contract was designed to be inherited by implementations of the `IConsensus` interface
/// that only need a simple mechanism of storage and retrieval of epoch hashes.
abstract contract AbstractConsensus is IConsensus {
    using LibInputRange for InputRange;

    /// @notice Indexes epoch hashes by DApp address, first input index and last input index.
    mapping(address => mapping(uint256 => mapping(uint256 => bytes32)))
        private _epochHashes;

    /// @notice Get the epoch hash for a certain DApp and input range.
    /// @param dapp The DApp contract address
    /// @param r The input range
    /// @return epochHash The epoch hash
    /// @dev For claimed epochs, returns the epoch hash of the last accepted claim.
    /// @dev For unclaimed epochs, returns `bytes32(0)`.
    function getEpochHash(
        address dapp,
        InputRange calldata r
    ) public view override returns (bytes32 epochHash) {
        epochHash = _epochHashes[dapp][r.firstInputIndex][r.lastInputIndex];
    }

    /// @notice Accept a claim.
    /// @param dapp The DApp contract address
    /// @param r The input range
    /// @param epochHash The epoch hash
    /// @dev Raises an `InputRangeIsEmptySet` error if `r` represents the empty set.
    /// @dev On successs, emits a `ClaimAcceptance` event.
    function _acceptClaim(
        address dapp,
        InputRange calldata r,
        bytes32 epochHash
    ) internal {
        if (r.isEmptySet()) {
            revert InputRangeIsEmptySet(dapp, r, epochHash);
        }
        _epochHashes[dapp][r.firstInputIndex][r.lastInputIndex] = epochHash;
        emit ClaimAcceptance(dapp, r, epochHash);
    }
}
