// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {BlockRange} from "../../common/BlockRange.sol";
import {EpochManager} from "../interfaces/EpochManager.sol";
import {EventEmitter} from "../interfaces/EventEmitter.sol";

abstract contract AbstractEpochManager is EpochManager {
    /// @notice The block number exclusive upper bounds of each sealed epoch.
    uint256[] private _sealedEpochEnds;

    /// @inheritdoc EpochManager
    function getNumberOfSealedEpochs() public view override returns (uint256) {
        return _sealedEpochEnds.length;
    }

    /// @inheritdoc EpochManager
    function getSealedEpochBoundaries(uint256 epochIndex)
        public
        view
        override
        returns (BlockRange memory)
    {
        return BlockRange({
            start: _getSealedEpochStart(epochIndex),
            end: _getSealedEpochEnd(epochIndex)
        });
    }

    /// @notice Seal a new epoch.
    function _sealEpoch() internal {
        uint256 epochIndex = getNumberOfSealedEpochs();
        uint256 start = _getSealedEpochStart(epochIndex);
        uint256 end = block.number;
        _sealedEpochEnds.push(end);
        emit EpochSealed(epochIndex, BlockRange({start: start, end: end}));
    }

    /// @notice Get the sealed epoch inclusive lower bound.
    function _getSealedEpochStart(uint256 epochIndex) internal view returns (uint256) {
        if (epochIndex > 0) {
            return _sealedEpochEnds[epochIndex - 1];
        } else {
            return getDeploymentBlockNumber();
        }
    }

    /// @notice Get the sealed epoch exclusive upper bound.
    function _getSealedEpochEnd(uint256 epochIndex) internal view returns (uint256) {
        return _sealedEpochEnds[epochIndex];
    }

    /// @inheritdoc EventEmitter
    function getDeploymentBlockNumber() public view virtual override returns (uint256);
}
