// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

/// @notice Manages epochs.
interface EpochManager {
    /// @notice The start of an epoch has been defined.
    /// @param epochIndex The index of the epoch
    /// @dev The block in which this event was emitted is
    /// the inclusive lower bound for the epoch boundary.
    event EpochOpened(uint256 indexed epochIndex);

    /// @notice The end of an epoch has been defined.
    /// @param epochIndex The index of the epoch
    /// @dev The block in which this event was emitted is
    /// the exclusive upper bound for the epoch boundary.
    event EpochClosed(uint256 indexed epochIndex);

    /// @notice The post-state of an epoch has been claimed.
    /// @param epochIndex The index of the epoch
    /// @param claimer The address of the claimer
    /// @param claimedPostEpochStateRoot The claimed post-epoch state root
    event PostEpochStateClaimed(
        uint256 indexed epochIndex,
        address indexed claimer,
        bytes32 indexed claimedPostEpochStateRoot
    );

    /// @notice The post-state of an epoch is being disputed.
    /// @param epochIndex The index of the epoch
    /// @param disputeResolutionModule The address of the dispute resolution module
    /// @param disputeResolutionAlgorithm The dispute resolution algorithm
    event EpochDisputed(
        uint256 indexed epochIndex,
        address indexed disputeResolutionModule,
        string disputeResolutionAlgorithm
    );

    /// @notice The post-state of an epoch has been defined.
    /// @param epochIndex The index of the epoch
    /// @param postEpochStateRoot The post-epoch state root
    /// @param postEpochOutputsRoot The post-epoch outputs root
    event EpochFinalized(
        uint256 indexed epochIndex,
        bytes32 indexed postEpochStateRoot,
        bytes32 indexed postEpochOutputsRoot
    );

    /// @notice Tried to close an epoch.
    /// @param epochIndex The index of the epoch
    /// @param reason Why the epoch cannot be closed
    error CannotCloseEpoch(uint256 epochIndex, string reason);

    /// @notice Tried to claim a post-epoch state.
    /// @param epochIndex The index of the epoch
    /// @param claimer The address of the claimer
    /// @param reason Why the claimer cannot be claim
    error CannotClaimPostEpochState(uint256 epochIndex, address claimer, string reason);

    /// @notice Tried to finalize an epoch.
    /// @param epochIndex The index of the epoch
    /// @param reason Why the epoch cannot be finalized
    error CannotFinalizeEpoch(uint256 epochIndex, string reason);

    /// @notice Check whether an epoch can be closed.
    /// @param epochIndex The epoch index
    /// @return canClose Whether the epoch can be closed
    /// @return reason If the epoch cannot be closed, the reason why
    function canCloseEpoch(uint256 epochIndex)
        external
        view
        returns (bool canClose, string memory reason);

    /// @notice Close an epoch.
    /// @param epochIndex The epoch index
    /// @dev One can check whether they can call this function
    /// by first calling the `canCloseEpoch` view function before
    /// and ensuring `canClose` is `true`. Otherwise, this function
    /// will raise a `CannotCloseEpoch` error with the epoch index
    /// and the same reason provided by `canCloseEpoch`.
    /// @dev If successful, emits an `EpochClosed` event for the
    /// referenced epoch and an `EpochOpened` for the epoch after it.
    function closeEpoch(uint256 epochIndex) external;

    /// @notice Check whether a claimer can claim a post-epoch state root.
    /// @param epochIndex The epoch index
    /// @param claimer The address of the claimer
    /// @return canClaim Whether the claimer can claim
    /// @return reason If the claimer cannot claim, the reason why
    function canClaimPostEpochState(uint256 epochIndex, address claimer)
        external
        view
        returns (bool canClaim, string memory reason);

    /// @notice Claim a post-epoch state root.
    /// @param epochIndex The epoch index
    /// @param postEpochStateRoot The post-epoch state root to claim
    /// @dev One can check whether they can call this function
    /// by first calling the `canClaimPostEpochState` view function before
    /// while passing the address of the account that will call this function
    /// and ensuring `canClaim` is `true`. Otherwise, this function
    /// will raise a `CannotClaimPostEpochState` error with the epoch index,
    /// the claimer address, and the same reason provided by `canClaimPostEpochState`.
    /// @dev If successful, emits a `PostEpochStateClaimed` event for the
    /// referenced epoch, claimer, and claimed post-epoch state root.
    function claimPostEpochState(uint256 epochIndex, bytes32 postEpochStateRoot)
        external;

    /// @notice Check whether an epoch can be finalized.
    /// @param epochIndex The epoch index
    /// @param postEpochStateRoot The post-epoch state root
    /// @param postEpochOutputsRoot The post-epoch outputs root
    /// @param proof The Merkle proof for the post-epoch outputs root
    /// @return canFinalize Whether the epoch can be finalized
    /// @return reason If the epoch cannot be finalized, the reason why
    function canFinalizeEpoch(
        uint256 epochIndex,
        bytes32 postEpochStateRoot,
        bytes32 postEpochOutputsRoot,
        bytes32[] calldata proof
    ) external view returns (bool canFinalize, string memory reason);

    /// @notice Finalize an epoch.
    /// @param epochIndex The epoch index
    /// @param postEpochStateRoot The post-epoch state root
    /// @param postEpochOutputsRoot The post-epoch outputs root
    /// @param proof The Merkle proof for the post-epoch outputs root
    /// @dev One can check whether they can call this function
    /// by first calling the `canFinalizeEpoch` view function before
    /// and ensuring `canFinalize` is `true`. Otherwise, this function
    /// will raise a `CannotFinalizeEpoch` error with the epoch index,
    /// post-epoch state and output roots, and Merkle proof,
    /// plus the same reason provided by `canFinalizeEpoch`.
    /// @dev If successful, emits an `EpochFinalized` event for the
    /// referenced epoch, post-epoch state and output roots.
    function finalizeEpoch(
        uint256 epochIndex,
        bytes32 postEpochStateRoot,
        bytes32 postEpochOutputsRoot,
        bytes32[] calldata proof
    ) external;
}
