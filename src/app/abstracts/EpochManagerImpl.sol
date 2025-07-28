// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {BlockRange} from "../../common/BlockRange.sol";
import {EpochManager} from "../interfaces/EpochManager.sol";
import {EventEmitter} from "../interfaces/EventEmitter.sol";

abstract contract EpochManagerImpl is EpochManager {
    /// @notice A closed epoch.
    /// @param exclusiveEnd The closed epoch exclusive end
    struct ClosedEpoch {
        uint256 exclusiveEnd;
    }

    /// @notice The array of closed epochs.
    ClosedEpoch[] private _closedEpochs;

    /// @inheritdoc EpochManager
    function getNumberOfClosedEpochs() public view override returns (uint256) {
        return _closedEpochs.length;
    }

    /// @inheritdoc EpochManager
    function getClosedEpochBoundaryExclusiveEnd(uint256 epochIndex)
        public
        view
        override
        returns (uint256)
    {
        return _closedEpochs[epochIndex].exclusiveEnd;
    }

    /// @inheritdoc EpochManager
    function getEpochBoundaryInclusiveStart(uint256 epochIndex)
        public
        view
        override
        returns (uint256)
    {
        return (epochIndex > 0)
            ? getClosedEpochBoundaryExclusiveEnd(epochIndex - 1)
            : getDeploymentBlockNumber();
    }

    /// @inheritdoc EventEmitter
    function getDeploymentBlockNumber() public view virtual override returns (uint256);

    /// @notice Close the (currently open) epoch.
    /// @dev Emits an `EpochClosed` event.
    function _closeEpoch() internal {
        uint256 epochIndex = getNumberOfClosedEpochs();
        uint256 inclusiveStart = getEpochBoundaryInclusiveStart(epochIndex);
        uint256 exclusiveEnd = block.number;
        _closedEpochs.push(ClosedEpoch(exclusiveEnd));
        emit EpochClosed(epochIndex, BlockRange(inclusiveStart, exclusiveEnd));
    }
}
