// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

/// @notice Manages epochs.
///
/// @dev We divide the input stream into epochs to guarantee the liveness of applications.
/// We use base-layer blocks as boundaries for input streams, since they are easy to work
/// with from off-chain. Epoch boundaries are defined as right-open intervals, like `[a,b)`.
/// Each epoch is either OPEN, CLOSED, or FINALIZED. Below, we explain each of these phases.
///
/// An OPEN epoch has a defined lower bound, as in `[a,?)`. The upper bound is undefined.
/// It can be closed as soon as the application receives some input, as we do not allow
/// closed epochs to be empty (that is, with no inputs). There is always some open epoch,
/// which receives any incoming input. The first epoch starts in the block in which the
/// application contract was deployed (which can be queried via `getDeploymentBlockNumber`).
///
/// A CLOSED epoch has both boundaries defined, as in `[a,b)`, and an assigned finalizer
/// contract. The closing of an epoch defines not only its exclusive upper bound,
/// but also the inclusive lower bound of the following epoch, which opens as soon as
/// the other one closes. So, at any given moment, there is always exactly one open epoch,
/// which receives any incoming input.  As soon as an epoch is closed, off-chain nodes can
/// compute the post-epoch state and submit it to the epoch finalizer, which is a
/// (potentially separate) contract responsible for making the epoch reach finality.
/// Its address is provided by the `EpochClosed` event and its interface (which is assumed
/// to be constant) is provided by the `getEpochFinalizerInterfaceId` view function.
///
/// A FINALIZED epoch has both boundaries and a post-epoch state defined.
/// A post-epoch state is the state of the application after processing all inputs
/// up until the end of that epoch. Fraud-proof systems use this post-epoch state as the
/// pre-epoch state of the next epoch, in case a dispute happens on the following epoch.
/// Along with the post-epoch state, the post-epoch outputs root is also defined, which
/// allows the validation and execution of any output emitted during that epoch, as well
/// as any output ever emitted up until that point.
///
/// Below is an example of an application and its epochs.
///
/// 1. Initially, the application has one epoch, which is open.
///    This epoch starts in the application deployment block, `a`.
///    The pre-epoch state is the genesis state, which is agreed upon.
///    The post-epoch state is unknown.
///
/// state 0 -> [a, ?) -> ?
///
/// 2. Eventually, a user sends an input. This allows someone to close
///    the open epoch (by calling `closeEpoch(0)`), which defines its upper bound,
///    as well as the lower bound of the next epoch (of index 1). This event also
///    creates an epoch finalizer contract, which is responsible for declaring
///    whether the epoch can be finalized and its post-epoch state. In the meantime,
///    the post-epoch state of both epochs are undefined.
///
/// state 0 -> [a, b) -> ? -> [b, ?) -> ?
///
/// 3. Eventually, the first epoch is declared finalized and someone is able to
///    call `finalizeEpoch` for the first epoch, also providing the post-epoch
///    outputs root and a proof of it. With this, the post-epoch state of the
///    first epoch is defined, which also serves as the pre-epoch state of the
///    second epoch. Now, the second epoch is the first non-finalized epoch.
///    If it is still empty, then it needs to wait for an input so that it
///    can be closed. If, otherwise, it received an input after the first epoch
///    was closed, then it can be closed at any moment and by anyone.
///
/// state 0 -> [a, b) -> state 1 -> [b, ?) -> ?
///
/// 4. The cycle repeats forever. As long as there are inputs and active validators
///    to close and finalize epochs, the app state will progress, and users will be
///    able to validate/execute new outputs.
///
interface EpochManager {
    /// @notice An epoch has been closed.
    /// @param epochIndex The index of the epoch
    /// @param epochFinalizer The contract that makes the epoch reach finality
    /// @dev An epoch is said to be closed if its boundaries are defined.
    /// We define epoch boundaries in terms of base-layer blocks.
    /// The block in which this event is emitted work both as
    /// the exclusive upper bound of the epoch that closed and
    /// the inclusive lower bound of the epoch that opened after it.
    /// The interface of the epoch finalizer contract is identified by
    /// the return value of the `getEpochFinalizerInterfaceId` view function.
    event EpochClosed(uint256 indexed epochIndex, address indexed epochFinalizer);

    /// @notice An epoch has been finalized.
    /// @param epochIndex The index of the epoch
    /// @param postEpochStateRoot The post-epoch state root
    /// @param postEpochOutputsRoot The post-epoch outputs root
    /// @dev An epoch is said to be finalized if its post-epoch state and outputs root are defined.
    event EpochFinalized(
        uint256 indexed epochIndex,
        bytes32 indexed postEpochStateRoot,
        bytes32 indexed postEpochOutputsRoot
    );

    /// @notice Tried to close an epoch that is open, but empty.
    /// @param epochIndex The epoch index
    /// @dev An epoch is said to be empty if it has no inputs.
    error CannotCloseEmptyEpoch(uint256 epochIndex);

    /// @notice Tried to close an epoch that is already closed.
    /// @param epochIndex The epoch index
    error EpochAlreadyClosed(uint256 epochIndex);

    /// @notice Tried to finalize an epoch that is still open.
    /// @param epochIndex The epoch index
    error CannotFinalizeOpenEpoch(uint256 epochIndex);

    /// @notice Tried to finalize an epoch, but the provided post-epoch state is invalid.
    /// @param epochIndex The epoch index
    /// @param postEpochStateRoot The post-epoch state root
    error InvalidPostEpochState(uint256 epochIndex, bytes32 postEpochStateRoot);

    /// @notice Tried to interact with an epoch that is not the first non-finalized epoch.
    /// @param epochIndex The provided epoch index
    error NotFirstNonFinalizedEpoch(uint256 epochIndex);

    /// @notice Tried to prove the post-epoch outputs root, but the proof length is invalid.
    /// @param proofLength The length of the provided proof
    /// @param expectedProofLength The expected proof length
    error InvalidOutputsRootProofLength(uint256 proofLength, uint256 expectedProofLength);

    /// @notice Get the epoch finalizer interface ID.
    /// @dev An interface ID is a bitwise XOR of function selectors.
    function getEpochFinalizerInterfaceId() external view returns (bytes4);

    /// @notice Get the number of finalized epochs.
    /// @dev Equivalent to the index of the first non-finalized epoch.
    function getFinalizedEpochCount()
        external
        view
        returns (uint256 finalizedEpochCount);

    /// @notice Check whether an epoch can be closed (via `closeEpoch`).
    /// @param epochIndex The epoch index
    /// @dev If the epoch can be closed, the function returns successfully.
    /// If the epoch is not the first non-finalized epoch, raises `NotFirstNonFinalizedEpoch`.
    /// If the epoch is already closed, raises `EpochAlreadyClosed`.
    /// If the epoch is open but still empty, raises `CannotCloseEmptyEpoch`.
    function canEpochBeClosed(uint256 epochIndex) external view;

    /// @notice Close an epoch.
    /// @param epochIndex The epoch index
    /// @dev Calls `canEpochBeClosed` internally.
    /// If the epoch can be closed, emits `EpochClosed`.
    function closeEpoch(uint256 epochIndex) external;

    /// @notice Check whether an epoch can be finalized (via `finalizeEpoch`).
    /// @param epochIndex The epoch index
    /// @param postEpochOutputsRoot The post-epoch outputs root
    /// @param proof The Merkle proof for the post-epoch outputs root
    /// @dev If the epoch can be finalized, returns successfully.
    /// If the epoch is not the first non-finalized epoch, raises `NotFirstNonFinalizedEpoch`.
    /// If the post-epoch outputs root proof length is invalid, raises `InvalidOutputsRootProofLength`.
    /// If the epoch is not closed yet, raises `CannotFinalizeOpenEpoch`.
    /// If the post-epoch state is invalid, raises `InvalidPostEpochState`.
    function canEpochBeFinalized(
        uint256 epochIndex,
        bytes32 postEpochOutputsRoot,
        bytes32[] calldata proof
    ) external view;

    /// @notice Finalize an epoch.
    /// @param epochIndex The epoch index
    /// @param postEpochOutputsRoot The post-epoch outputs root
    /// @param proof The Merkle proof for the post-epoch outputs root
    /// @dev Calls `canEpochBeFinalized` internally.
    /// If the epoch can be finalized, emits `EpochFinalized`.
    function finalizeEpoch(
        uint256 epochIndex,
        bytes32 postEpochOutputsRoot,
        bytes32[] calldata proof
    ) external;

    /// @notice Check whether an outputs root has been finalized already.
    /// @param outputsRoot The outputs Merkle tree root
    /// @return isFinal Whether the outputs root is final
    /// @dev Useful for validating/executing outputs.
    function isOutputsRootFinal(bytes32 outputsRoot)
        external
        view
        returns (bool isFinal);
}
