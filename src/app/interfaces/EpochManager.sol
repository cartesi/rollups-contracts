// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {BlockRange} from "../../common/BlockRange.sol";
import {EventEmitter} from "./EventEmitter.sol";

/// @notice Manages sealed epochs and their boundaries.
interface EpochManager is EventEmitter {
    /// @notice An epoch was sealed.
    /// @param epochIndex The index of the epoch
    /// @param epochBoundaries The epoch boundaries
    /// @dev Epoch indices are zero-based and incremental.
    event EpochSealed(uint256 indexed epochIndex, BlockRange epochBoundaries);

    /// @notice Get the number of sealed epochs.
    function getNumberOfSealedEpochs() external view returns (uint256);

    /// @notice Get the boundaries of a sealed epoch by its index.
    /// @param epochIndex The epoch index
    /// @return epochBoundaries The epoch boundaries
    /// @dev Valid epoch indices are within the range `[0, N)`.
    /// @dev See  `getNumberOfSealedEpochs` for the value of `N`.
    function getSealedEpochBoundaries(uint256 epochIndex)
        external
        view
        returns (BlockRange memory epochBoundaries);
}
