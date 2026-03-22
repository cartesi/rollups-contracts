// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.26;

import {ERC165} from "@openzeppelin-contracts-5.2.0/utils/introspection/ERC165.sol";
import {IERC165} from "@openzeppelin-contracts-5.2.0/utils/introspection/IERC165.sol";

import {CanonicalMachine} from "../common/CanonicalMachine.sol";
import {RollupsContract} from "../common/RollupsContract.sol";
import {ApplicationChecker} from "../dapp/ApplicationChecker.sol";
import {LibBinaryMerkleTree} from "../library/LibBinaryMerkleTree.sol";
import {LibKeccak256} from "../library/LibKeccak256.sol";
import {IConsensus} from "./IConsensus.sol";
import {IOutputsMerkleRootValidator} from "./IOutputsMerkleRootValidator.sol";

/// @notice Abstract implementation of IConsensus
abstract contract AbstractConsensus is
    IConsensus,
    ERC165,
    ApplicationChecker,
    RollupsContract
{
    using LibBinaryMerkleTree for bytes32[];

    /// @notice The epoch length
    uint256 immutable EPOCH_LENGTH;

    /// @notice Indexes accepted claims by application contract address.
    mapping(address => mapping(bytes32 => bool)) private _validOutputsMerkleRoots;

    /// @notice Indexes number of the first unprocessed block
    /// by application contract address.
    mapping(address => uint256) private _firstUnprocessedBlockNumbers;

    /// @notice Indexes machine merkle root of the most recently accepted claim
    /// by application contract address.
    mapping(address => bytes32) private _lastFinalizedMachineMerkleRoots;

    /// @notice Indexes number of claims accepted to the consensus
    /// by application contract address.
    /// @dev Must be monotonically non-decreasing in time
    mapping(address => uint256) private _numOfAcceptedClaims;

    /// @notice Indexes number of claims submitted to the consensus
    /// by application contract address.
    /// @dev Must be monotonically non-decreasing in time
    mapping(address => uint256) private _numOfSubmittedClaims;

    /// @param epochLength The epoch length
    /// @dev Reverts if the epoch length is zero.
    constructor(uint256 epochLength) {
        require(epochLength > 0, "epoch length must not be zero");
        EPOCH_LENGTH = epochLength;
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

    function getLastFinalizedMachineMerkleRoot(address appContract)
        public
        view
        override
        returns (bytes32)
    {
        return _lastFinalizedMachineMerkleRoots[appContract];
    }

    /// @inheritdoc IConsensus
    function getEpochLength() public view override returns (uint256) {
        return EPOCH_LENGTH;
    }

    /// @inheritdoc IConsensus
    function getNumberOfAcceptedClaims(address appContract)
        external
        view
        override
        returns (uint256)
    {
        return _numOfAcceptedClaims[appContract];
    }

    /// @inheritdoc IConsensus
    function getNumberOfSubmittedClaims(address appContract)
        external
        view
        override
        returns (uint256)
    {
        return _numOfSubmittedClaims[appContract];
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
            lastProcessedBlockNumber % EPOCH_LENGTH == (EPOCH_LENGTH - 1),
            NotEpochFinalBlock(lastProcessedBlockNumber, EPOCH_LENGTH)
        );
        {
            uint256 upperBound = block.number;
            require(
                lastProcessedBlockNumber < upperBound,
                NotPastBlock(lastProcessedBlockNumber, upperBound)
            );
        }
    }

    /// @notice Submit a claim.
    /// @param submitter The submitter address
    /// @param appContract The application contract address
    /// @param lastProcessedBlockNumber The number of the last processed block
    /// @param outputsMerkleRoot The output Merkle root
    /// @param machineMerkleRoot The machine Merkle root
    /// @dev Assumes outputs Merkle root is proven to be at the start of the machine TX buffer.
    /// @dev Checks whether the app is foreclosed.
    /// @dev Emits a `ClaimSubmitted` event.
    function _submitClaim(
        address submitter,
        address appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 outputsMerkleRoot,
        bytes32 machineMerkleRoot
    ) internal notForeclosed(appContract) {
        emit ClaimSubmitted(
            submitter,
            appContract,
            lastProcessedBlockNumber,
            outputsMerkleRoot,
            machineMerkleRoot
        );
        ++_numOfSubmittedClaims[appContract];
    }

    /// @notice Accept a claim.
    /// @param appContract The application contract address
    /// @param lastProcessedBlockNumber The number of the last processed block
    /// @param outputsMerkleRoot The output Merkle root
    /// @param machineMerkleRoot The machine Merkle root
    /// @dev Assumes outputs Merkle root is proven to be at the start of the machine TX buffer.
    /// @dev Checks whether the app is foreclosed.
    /// @dev Marks the outputsMerkleRoot as valid.
    /// @dev Emits a `ClaimAccepted` event.
    function _acceptClaim(
        address appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 outputsMerkleRoot,
        bytes32 machineMerkleRoot
    ) internal notForeclosed(appContract) {
        _validOutputsMerkleRoots[appContract][outputsMerkleRoot] = true;
        if (lastProcessedBlockNumber >= _firstUnprocessedBlockNumbers[appContract]) {
            _lastFinalizedMachineMerkleRoots[appContract] = machineMerkleRoot;
            _firstUnprocessedBlockNumbers[appContract] = lastProcessedBlockNumber + 1;
        }
        emit ClaimAccepted(
            appContract, lastProcessedBlockNumber, outputsMerkleRoot, machineMerkleRoot
        );
        ++_numOfAcceptedClaims[appContract];
    }

    /// @notice Compute the machine Merkle root given an outputs Merkle root and a proof.
    /// @param outputsMerkleRoot The outputs Merkle root
    /// @param proof The bottom-up Merkle proof of the outputs Merkle root at the start of the machine TX buffer
    /// @return machineMerkleRoot The machine Merkle root
    function _computeMachineMerkleRoot(
        bytes32 outputsMerkleRoot,
        bytes32[] calldata proof
    ) internal pure returns (bytes32 machineMerkleRoot) {
        _checkProofSize(proof.length, CanonicalMachine.MEMORY_TREE_HEIGHT);
        machineMerkleRoot = proof.merkleRootAfterReplacement(
            CanonicalMachine.TX_BUFFER_START >> CanonicalMachine.LOG2_DATA_BLOCK_SIZE,
            keccak256(abi.encode(outputsMerkleRoot)),
            LibKeccak256.hashPair
        );
    }

    /// @notice Check the size of a supplied proof against the expected proof size.
    /// @param suppliedProofSize Supplied proof size
    /// @param expectedProofSize Expected proof size
    /// @dev Raises an `InvalidOutputsMerkleRootProofSize` error if sizes differ.
    function _checkProofSize(uint256 suppliedProofSize, uint256 expectedProofSize)
        internal
        pure
    {
        require(
            suppliedProofSize == expectedProofSize,
            InvalidOutputsMerkleRootProofSize(suppliedProofSize, expectedProofSize)
        );
    }
}
