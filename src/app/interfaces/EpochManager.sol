// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

/// @notice Manages epochs.
interface EpochManager {
    /// @notice An epoch has been closed.
    /// @param epochIndex The index of the epoch
    /// @param epochFinalizer The contract that makes the epoch reach finality
    /// @dev An epoch is said to be closed if its boundaries are defined.
    /// We define epoch boundaries in terms of base-laye
    /// The number of the block in which this event was emitted is both
    /// the block number exclusive upper bound of the epoch that has been closed
    /// and the block number inclusive lower bound of the epoch following it.
    /// The interface of the epoch finalizer contract can be inferred
    /// from the return value of the `getEpochFinalizerInterfaceId` view function.
    event EpochClosed(uint256 indexed epochIndex, address indexed epochFinalizer);

    /// @notice An epoch has been finalized.
    /// @param epochIndex The index of the epoch
    /// @param postEpochStateRoot The post-epoch state root
    /// @param postEpochOutputsRoot The post-epoch outputs root
    event EpochFinalized(
        uint256 indexed epochIndex,
        bytes32 indexed postEpochStateRoot,
        bytes32 indexed postEpochOutputsRoot
    );

    /// @notice Tried to close the current epoch, which is open, but it is still empty.
    /// @param currentEpochIndex The current epoch index
    /// @dev An epoch is said to be empty if it has no inputs.
    error CannotCloseEmptyEpoch(uint256 currentEpochIndex);

    /// @notice Tried to close the current epoch, but it is already closed.
    /// @param currentEpochIndex The current epoch index
    error CannotCloseAlreadyClosedEpoch(uint256 currentEpochIndex);

    /// @notice Tried to finalize the current epoch, but it is not closed.
    /// @param currentEpochIndex The current epoch index
    error CannotFinalizeOpenEpoch(uint256 currentEpochIndex);

    /// @notice Tried to finalize the current epoch, which is closed, but with the wrong post-epoch state.
    /// @param currentEpochIndex The current epoch index
    error CannotFinalizeEpochWithWrongPostEpochState(uint256 currentEpochIndex);

    /// @notice Tried to interact with an epoch that is not the current one.
    /// @param providedEpochIndex The provided epoch index
    /// @param currentEpochIndex The current epoch index
    error InvalidCurrentEpochIndex(uint256 providedEpochIndex, uint256 currentEpochIndex);

    /// @notice Tried to prove the post-epoch outputs root, but the proof is invalid.
    error InvalidPostEpochOutputsRootProof();

    /// @notice Get the epoch finalizer interface ID.
    /// @dev An interface ID is a bitwise XOR of function selectors.
    function getEpochFinalizerInterfaceId() external view returns (bytes4);

    /// @notice Get the current epoch index.
    function getCurrentEpochIndex() external view returns (uint256);

    /// @notice Ensure the current epoch can be closed (via `closeEpoch`).
    /// @return currentEpochIndex The current epoch index
    /// @dev If the current epoch can be closed, returns the current epoch index.
    /// If the current epoch is open but still empty, raises `CannotCloseEmptyEpoch`.
    /// If the current epoch is already close, raises `CannotCloseAlreadyClosedEpoch`.
    function ensureCurrentEpochCanBeClosed()
        external
        view
        returns (uint256 currentEpochIndex);

    /// @notice Close an epoch.
    /// @param epochIndex The epoch index
    /// @dev If the epoch index is not the current epoch index, raises `InvalidCurrentEpochIndex`.
    /// If the current epoch cannot be closed, raises an error (see `ensureCurrentEpochCanBeClosed`).
    /// If the current epoch can be closed, emits `EpochClosed`.
    function closeEpoch(uint256 epochIndex) external;

    /// @notice Ensure the current epoch can be finalized (via `finalizeEpoch`).
    /// @param postEpochStateRoot The post-epoch state root
    /// @param postEpochOutputsRoot The post-epoch outputs root
    /// @param proof The Merkle proof for the post-epoch outputs root
    /// @return currentEpochIndex The current epoch index
    /// @dev If the current epoch can be finalized, returns the current epoch index.
    /// If the current epoch is not closed yet, raises `CannotFinalizeOpenEpoch`.
    /// If the post-epoch state is not final, raises `CannotFinalizeEpochWithWrongPostEpochState`.
    /// If the post-epoch outputs root proof is invalid, raises `InvalidPostEpochOutputsRootProof`.
    function ensureCurrentEpochCanBeFinalized(
        bytes32 postEpochStateRoot,
        bytes32 postEpochOutputsRoot,
        bytes32[] calldata proof
    ) external view returns (uint256 currentEpochIndex);

    /// @notice Finalize an epoch.
    /// @param epochIndex The epoch index
    /// @param postEpochStateRoot The post-epoch state root
    /// @param postEpochOutputsRoot The post-epoch outputs root
    /// @param proof The Merkle proof for the post-epoch outputs root
    /// @dev If the epoch index is not the current epoch index, raises `InvalidCurrentEpochIndex`.
    /// If the current epoch cannot be finalized, raises an error (see `ensureCurrentEpochCanBeFinalized`).
    /// If the current epoch can be finalized, emits `EpochFinalized`.
    function finalizeEpoch(
        uint256 epochIndex,
        bytes32 postEpochStateRoot,
        bytes32 postEpochOutputsRoot,
        bytes32[] calldata proof
    ) external;
}
