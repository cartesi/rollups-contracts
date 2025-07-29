// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {ITournament} from "prt-contracts/ITournament.sol";

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

    /// @notice The post-state of an epoch is being disputed.
    /// @param epochIndex The index of the epoch
    /// @param tournament The tournament contract
    event EpochDisputed(uint256 indexed epochIndex, ITournament tournament);

    /// @notice The post-state of an epoch has been defined.
    /// @param epochIndex The index of the epoch
    /// @param postEpochStateRoot The post-epoch state root
    event EpochFinalized(uint256 indexed epochIndex, bytes32 postEpochStateRoot);
}
