// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.26;

import {ERC165} from "@openzeppelin-contracts-5.2.0/utils/introspection/ERC165.sol";
import {IERC165} from "@openzeppelin-contracts-5.2.0/utils/introspection/IERC165.sol";

import {IOutputsMerkleRootValidator} from "./IOutputsMerkleRootValidator.sol";
import {IConsensus} from "./IConsensus.sol";

/// @notice Abstract implementation of IConsensus
abstract contract AbstractConsensus is IConsensus, ERC165 {
    /// @notice The epoch length
    uint256 internal immutable _epochLength;

    /// @notice Indexes accepted claims by application contract address.
    mapping(address => mapping(bytes32 => bool)) private _validOutputsMerkleRoots;

    /// @param epochLength The epoch length
    /// @dev Reverts if the epoch length is zero.
    constructor(uint256 epochLength) {
        require(epochLength > 0, "epoch length must not be zero");
        _epochLength = epochLength;
    }

    /// @inheritdoc IOutputsMerkleRootValidator
    function isOutputsMerkleRootValid(address appContract, bytes32 outputsMerkleRoot)
        public
        view
        override
        returns (bool)
    {
        return _validOutputsMerkleRoots[appContract][outputsMerkleRoot];
    }

    /// @inheritdoc IConsensus
    function getEpochLength() public view override returns (uint256) {
        return _epochLength;
    }

    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165, ERC165)
        returns (bool)
    {
        return interfaceId == type(IConsensus).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /// @notice Validate a last processed block number.
    /// @param lastProcessedBlockNumber The number of the last processed block
    function _validateLastProcessedBlockNumber(uint256 lastProcessedBlockNumber)
        internal
        view
    {
        require(
            lastProcessedBlockNumber % _epochLength == (_epochLength - 1),
            NotEpochFinalBlock(lastProcessedBlockNumber, _epochLength)
        );
        {
            uint256 upperBound = block.number;
            require(
                lastProcessedBlockNumber < upperBound,
                NotPastBlock(lastProcessedBlockNumber, upperBound)
            );
        }
    }

    /// @notice Accept a claim.
    /// @param appContract The application contract address
    /// @param lastProcessedBlockNumber The number of the last processed block
    /// @param outputsMerkleRoot The output Merkle root hash
    /// @dev Marks the outputsMerkleRoot as valid.
    /// @dev Emits a `ClaimAccepted` event.
    function _acceptClaim(
        address appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 outputsMerkleRoot
    ) internal {
        _validOutputsMerkleRoots[appContract][outputsMerkleRoot] = true;
        emit ClaimAccepted(appContract, lastProcessedBlockNumber, outputsMerkleRoot);
    }
}
