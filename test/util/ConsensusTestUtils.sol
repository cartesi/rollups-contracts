// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {IConsensus} from "src/consensus/IConsensus.sol";

import {ApplicationCheckerTestUtils} from "./ApplicationCheckerTestUtils.sol";

contract ConsensusTestUtils is ApplicationCheckerTestUtils {
    function _encodeNotPastBlock(uint256 lastProcessedBlockNumber)
        internal
        view
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IConsensus.NotPastBlock.selector,
            lastProcessedBlockNumber,
            vm.getBlockNumber()
        );
    }

    function _encodeNotFirstClaim(address appContract, uint256 lastProcessedBlockNumber)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IConsensus.NotFirstClaim.selector, appContract, lastProcessedBlockNumber
        );
    }

    function _encodeNotEpochFinalBlock(
        uint256 lastProcessedBlockNumber,
        uint256 epochLength
    ) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            IConsensus.NotEpochFinalBlock.selector, lastProcessedBlockNumber, epochLength
        );
    }

    function _maxEpochIndex(uint256 epochLength) internal pure returns (uint256) {
        return (type(uint256).max - (epochLength - 1)) / epochLength;
    }

    function _minFutureEpochIndex(uint256 epochLength) internal view returns (uint256) {
        return (vm.getBlockNumber() + 1) / epochLength;
    }

    function _randomFutureEpochIndex(uint256 epochLength) internal returns (uint256) {
        return
            vm.randomUint(_minFutureEpochIndex(epochLength), _maxEpochIndex(epochLength));
    }

    function _randomFutureEpochFinalBlockNumber(uint256 epochLength)
        internal
        returns (uint256)
    {
        return _randomFutureEpochIndex(epochLength) * epochLength + (epochLength - 1);
    }

    function _randomUintGt(uint256 n) internal returns (uint256) {
        vm.assume(n <= type(uint256).max - 1);
        return vm.randomUint(n + 1, type(uint256).max);
    }

    function _randomNonEpochFinalBlock(uint256 epochLength) internal returns (uint256) {
        // If epochLength == 1, then forall x, (x % epochLength) == (epochLength - 1).
        // That is, every block is an epoch final block, so we cannot sample a random
        // non-epoch-final block.
        vm.assume(epochLength >= 2);

        // Pick a random blockNumber that satisfies both
        // - blockNumber % epochLength != (epochLength - 1)
        // - blockNumber > currentBlockNumber
        uint256 blockNumber = _randomUintGt(vm.getBlockNumber());
        vm.assume(blockNumber % epochLength != (epochLength - 1));

        return blockNumber;
    }

    function _randomBytes32DifferentFrom(bytes32 value)
        internal
        returns (bytes32 otherValue)
    {
        while (true) {
            otherValue = bytes32(vm.randomUint());
            if (otherValue != value) {
                break;
            }
        }
    }
}
