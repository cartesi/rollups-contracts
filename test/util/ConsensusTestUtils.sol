// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Memory} from "cartesi-machine-solidity-step-0.13.0/src/Memory.sol";

import {IConsensus} from "src/consensus/IConsensus.sol";

import {ApplicationCheckerTestUtils} from "./ApplicationCheckerTestUtils.sol";
import {Claim} from "./Claim.sol";
import {LibClaim} from "./LibClaim.sol";

contract ConsensusTestUtils is ApplicationCheckerTestUtils {
    using LibClaim for Claim;

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

    function _encodeInvalidOutputsMerkleRootProofSize(uint256 proofSize)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IConsensus.InvalidOutputsMerkleRootProofSize.selector,
            proofSize,
            Memory.LOG2_MAX_SIZE
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

    function _randomBytes32() internal returns (bytes32) {
        return bytes32(vm.randomUint());
    }

    function _randomProof(uint256 length) internal returns (bytes32[] memory proof) {
        proof = new bytes32[](length);
        for (uint256 i; i < proof.length; ++i) {
            proof[i] = _randomBytes32();
        }
    }

    function _randomLeafProof() internal returns (bytes32[] memory proof) {
        return _randomProof(Memory.LOG2_MAX_SIZE);
    }

    function _randomClaimDifferentFrom(Claim memory claim, bytes32 machineMerkleRoot)
        internal
        returns (Claim memory otherClaim, bytes32 otherMachineMerkleRoot)
    {
        otherClaim.appContract = claim.appContract;
        otherClaim.lastProcessedBlockNumber = claim.lastProcessedBlockNumber;
        while (true) {
            otherClaim.outputsMerkleRoot = _randomBytes32();
            otherClaim.proof = _randomProof(claim.proof.length);
            otherMachineMerkleRoot = otherClaim.computeMachineMerkleRoot();
            if (machineMerkleRoot != otherMachineMerkleRoot) {
                break;
            }
        }
    }

    function _randomInvalidLeafProofSize() internal returns (uint256 proofSize) {
        while (true) {
            proofSize = vm.randomUint(0, 2 * Memory.LOG2_MAX_SIZE + 1);
            if (proofSize != Memory.LOG2_MAX_SIZE) {
                break;
            }
        }
    }
}
