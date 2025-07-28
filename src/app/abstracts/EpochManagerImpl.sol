// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {BlockRange} from "../../common/BlockRange.sol";
import {EpochManager} from "../interfaces/EpochManager.sol";
import {EventEmitter} from "../interfaces/EventEmitter.sol";

abstract contract EpochManagerImpl is EpochManager {
    /// @notice A sealed epoch.
    /// @param exclusiveEnd The sealed epoch exclusive end
    struct SealedEpoch {
        uint256 exclusiveEnd;
    }

    /// @notice The array of sealed epochs.
    SealedEpoch[] private _sealedEpochs;

    /// @inheritdoc EpochManager
    function getNumberOfSealedEpochs() public view override returns (uint256) {
        return _sealedEpochs.length;
    }

    /// @inheritdoc EpochManager
    function getSealedEpochBoundaries(uint256 epochIndex)
        public
        view
        override
        returns (BlockRange memory)
    {
        return BlockRange({
            inclusiveStart: _getSealedEpochInclusiveStart(epochIndex),
            exclusiveEnd: _getSealedEpochExclusiveEnd(epochIndex)
        });
    }

    /// @notice Seal a new epoch.
    function _sealEpoch() internal {
        uint256 epochIndex = getNumberOfSealedEpochs();
        uint256 inclusiveStart = _getSealedEpochInclusiveStart(epochIndex);
        uint256 exclusiveEnd = block.number;
        _sealedEpochs.push(SealedEpoch(exclusiveEnd));
        emit EpochSealed(epochIndex, BlockRange(inclusiveStart, exclusiveEnd));
    }

    /// @notice Get the sealed epoch inclusive lower bound.
    function _getSealedEpochInclusiveStart(uint256 epochIndex)
        internal
        view
        returns (uint256)
    {
        return (epochIndex > 0)
            ? _sealedEpochs[epochIndex - 1].exclusiveEnd
            : getDeploymentBlockNumber();
    }

    /// @notice Get the sealed epoch exclusive upper bound.
    function _getSealedEpochExclusiveEnd(uint256 epochIndex)
        internal
        view
        returns (uint256)
    {
        return _sealedEpochs[epochIndex].exclusiveEnd;
    }

    /// @inheritdoc EventEmitter
    function getDeploymentBlockNumber() public view virtual override returns (uint256);
}
