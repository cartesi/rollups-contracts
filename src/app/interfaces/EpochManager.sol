// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {BlockRange} from "../../common/BlockRange.sol";
import {EventEmitter} from "./EventEmitter.sol";

/// @notice Manages sealed epochs and their boundaries.
interface EpochManager is EventEmitter {
    /// @notice An epoch was closed.
    /// @param epochIndex The index of the epoch
    /// @param epochBoundaries The epoch boundaries
    /// @dev Epoch indices are zero-based and incremental.
    /// @dev At the same time as this epoch closed, another epoch
    /// has opened starting from the exclusive end of this epoch.
    event EpochClosed(uint256 indexed epochIndex, BlockRange epochBoundaries);

    /// @notice Get the number of closed epochs.
    /// @dev Equivalent to the index of the open epoch.
    function getNumberOfClosedEpochs() external view returns (uint256);

    /// @notice Get the boundary inclusive start of an epoch.
    /// @param epochIndex The epoch index
    /// @dev Valid epoch indices are within the range `[0, N]`.
    /// @dev See  `getNumberOfClosedEpochs` for the value of `N`.
    function getEpochBoundaryInclusiveStart(uint256 epochIndex)
        external
        view
        returns (uint256);

    /// @notice Get the boundary exclusive end of a closed epoch.
    /// @param epochIndex The epoch index
    /// @dev Valid closed epoch indices are within the range `[0, N)`.
    /// @dev See  `getNumberOfClosedEpochs` for the value of `N`.
    function getClosedEpochBoundaryExclusiveEnd(uint256 epochIndex)
        external
        view
        returns (uint256);
}
