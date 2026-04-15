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
import {IConsensusFactoryErrors} from "./IConsensusFactoryErrors.sol";
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

    /// @notice The claim staging period
    uint256 immutable CLAIM_STAGING_PERIOD;

    /// @notice Indexes valid outputs Merkle roots by application contract address.
    mapping(address => mapping(bytes32 => bool)) private _validOutputsMerkleRoots;

    /// @notice Indexes claim information by application contract address,
    /// last-processed block number, and machine Merkle root.
    mapping(address => mapping(uint256 => mapping(bytes32 => Claim))) private _claims;

    /// @notice Indexes number of the first unprocessed block
    /// by application contract address.
    mapping(address => uint256) private _firstUnprocessedBlockNumbers;

    /// @notice Indexes machine merkle root of the most recently accepted claim
    /// by application contract address.
    mapping(address => bytes32) private _lastFinalizedMachineMerkleRoots;

    /// @notice Indexes number of accepted claims by application contract address.
    /// @dev Must be monotonically non-decreasing in time
    mapping(address => uint256) private _numOfAcceptedClaims;

    /// @notice Indexes number of staged claims by application contract address.
    /// @dev Must be monotonically non-decreasing in time
    mapping(address => uint256) private _numOfStagedClaims;

    /// @notice Indexes number of submitted claims by application contract address.
    /// @dev Must be monotonically non-decreasing in time
    mapping(address => uint256) private _numOfSubmittedClaims;

    /// @param epochLength The epoch length
    /// @param claimStagingPeriod The claim staging period
    /// @dev Reverts if the epoch length is zero.
    constructor(uint256 epochLength, uint256 claimStagingPeriod) {
        require(epochLength > 0, IConsensusFactoryErrors.ZeroEpochLength());
        EPOCH_LENGTH = epochLength;
        CLAIM_STAGING_PERIOD = claimStagingPeriod;
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

    function getClaimStagingPeriod() public view override returns (uint256) {
        return CLAIM_STAGING_PERIOD;
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

    function getNumberOfStagedClaims(address appContract)
        external
        view
        override
        returns (uint256)
    {
        return _numOfStagedClaims[appContract];
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

    function getClaim(
        address appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 machineMerkleRoot
    ) public view override returns (Claim memory claim) {
        claim = _claims[appContract][lastProcessedBlockNumber][machineMerkleRoot];
    }

    function acceptClaim(
        address appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 machineMerkleRoot
    ) external override notForeclosed(appContract) {
        _validateLastProcessedBlockNumber(lastProcessedBlockNumber);
        Claim storage claim;
        claim = _claims[appContract][lastProcessedBlockNumber][machineMerkleRoot];
        require(
            claim.status == ClaimStatus.STAGED,
            ClaimNotStaged(
                appContract, lastProcessedBlockNumber, machineMerkleRoot, claim.status
            )
        );
        // We assume `block.number >= stagingBlockNumber` because when the claim is
        // staged, we know `stagingBlockNumber` was assigned an evaluation of
        // `block.number` in the current or in a previous block. Even if this assumption
        // were wrong, the evaluation of the subtraction expression would raise an
        // arithmetic-underflow error, leading to a liveness issue, but not a safety one,
        // in which case the guardian could foreclose the application, and users could
        // withdraw their funds. We opt not to phrase the inequality like (the perhaps
        // more intuitive) `stagingBlockNumber + getClaimStagingPeriod() <= block.number`
        // because the addition could overflow if the claim staging period were set to an
        // unusually-high value.
        {
            uint256 numberOfBlocksAfterStaging = block.number - claim.stagingBlockNumber;
            uint256 claimStagingPeriod = getClaimStagingPeriod();
            require(
                numberOfBlocksAfterStaging >= claimStagingPeriod,
                ClaimStagingPeriodNotOverYet(
                    appContract,
                    lastProcessedBlockNumber,
                    machineMerkleRoot,
                    numberOfBlocksAfterStaging,
                    claimStagingPeriod
                )
            );
        }
        claim.status = ClaimStatus.ACCEPTED;
        _validOutputsMerkleRoots[appContract][claim.stagedOutputsMerkleRoot] = true;
        if (lastProcessedBlockNumber >= _firstUnprocessedBlockNumbers[appContract]) {
            _lastFinalizedMachineMerkleRoots[appContract] = machineMerkleRoot;
            _firstUnprocessedBlockNumbers[appContract] = lastProcessedBlockNumber + 1;
        }
        emit ClaimAccepted(
            appContract,
            lastProcessedBlockNumber,
            claim.stagedOutputsMerkleRoot,
            machineMerkleRoot
        );
        ++_numOfAcceptedClaims[appContract];
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
    /// @dev Assumes the last processed block number is valid.
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

    /// @notice Stage a claim (if unstaged).
    /// @param appContract The application contract address
    /// @param lastProcessedBlockNumber The number of the last processed block
    /// @param outputsMerkleRoot The output Merkle root
    /// @param machineMerkleRoot The machine Merkle root
    /// @dev Assumes outputs Merkle root is proven to be at the start of the machine TX buffer.
    /// @dev Assumes the last processed block number is valid.
    /// @dev Assumes the claim was previously submitted.
    /// @dev Checks whether the app is foreclosed.
    /// @dev Marks the claim as staged (if unstaged).
    /// @dev Emits a `ClaimStaged` event (if unstaged).
    function _stageClaim(
        address appContract,
        uint256 lastProcessedBlockNumber,
        bytes32 outputsMerkleRoot,
        bytes32 machineMerkleRoot
    ) internal notForeclosed(appContract) {
        Claim storage claim;
        claim = _claims[appContract][lastProcessedBlockNumber][machineMerkleRoot];
        if (claim.status == ClaimStatus.UNSTAGED) {
            claim.stagingBlockNumber = block.number;
            claim.stagedOutputsMerkleRoot = outputsMerkleRoot;
            claim.status = ClaimStatus.STAGED;
            emit ClaimStaged(
                appContract,
                lastProcessedBlockNumber,
                outputsMerkleRoot,
                machineMerkleRoot
            );
            ++_numOfStagedClaims[appContract];
        }
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
