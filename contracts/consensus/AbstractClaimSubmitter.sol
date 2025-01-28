// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IConsensus} from "./IConsensus.sol";
import {IClaimSubmitter} from "./IClaimSubmitter.sol";

/// @notice Stores accepted claims for several applications.
/// @dev This contract was designed to be inherited by implementations of the `IClaimSubmitter` interface
/// that only need a simple mechanism of storage and retrieval of accepted claims.
abstract contract AbstractClaimSubmitter is IClaimSubmitter, ERC165 {
    /// @notice The epoch length
    uint256 private immutable _epochLength;

    /// @notice Indexes accepted claims by application contract address.
    mapping(address => mapping(bytes32 => bool)) private _acceptedClaims;

    /// @param epochLength The epoch length
    /// @dev Reverts if the epoch length is zero.
    constructor(uint256 epochLength) {
        require(epochLength > 0, "epoch length must not be zero");
        _epochLength = epochLength;
    }

    /// @inheritdoc IConsensus
    function wasClaimAccepted(
        address appContract,
        bytes32 claim
    ) public view override returns (bool) {
        return _acceptedClaims[appContract][claim];
    }

    /// @inheritdoc IClaimSubmitter
    function getEpochLength() public view override returns (uint256) {
        return _epochLength;
    }

    /// @inheritdoc ERC165
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165, ERC165) returns (bool) {
        return
            interfaceId == type(IClaimSubmitter).interfaceId ||
            super.supportsInterface(interfaceId);
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
