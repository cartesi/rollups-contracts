// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {CanonicalMachine} from "../common/CanonicalMachine.sol";
import {MerkleV2} from "@cartesi/util/contracts/MerkleV2.sol";
import {Outputs} from "../common/Outputs.sol";
import {OutputValidityProof} from "../common/OutputValidityProof.sol";

library LibOutputValidityProof {
    using CanonicalMachine for CanonicalMachine.Log2Size;

    /// @notice Check if epoch hash is valid
    /// @param v The output validity proof
    /// @param epochHash The epoch hash
    function isEpochHashValid(
        OutputValidityProof calldata v,
        bytes32 epochHash
    ) internal pure returns (bool) {
        return
            epochHash ==
            keccak256(abi.encode(v.outputsEpochRootHash, v.machineStateHash));
    }

    /// @notice Check if the outputs epoch root hash is valid
    /// @param v The output validity proof
    function isOutputsEpochRootHashValid(
        OutputValidityProof calldata v
    ) internal pure returns (bool) {
        return
            v.outputsEpochRootHash ==
            MerkleV2.getRootAfterReplacementInDrive(
                CanonicalMachine.getIntraMemoryRangePosition(
                    v.inputIndexWithinEpoch,
                    CanonicalMachine.KECCAK_LOG2_SIZE
                ),
                CanonicalMachine.KECCAK_LOG2_SIZE.uint64OfSize(),
                CanonicalMachine.EPOCH_OUTPUT_LOG2_SIZE.uint64OfSize(),
                v.outputHashesRootHash,
                v.outputHashesInEpochSiblings
            );
    }

    /// @notice Check if the output hashes root hash is valid
    /// @param v The output validity proof
    /// @param output The output
    /// @dev The hash of the output is converted to bytes (abi.encode) and
    /// treated as data. The metadata output memory range stores that data while
    /// being indifferent to its contents. To prove that the received
    /// output is contained in the metadata output memory range we need to
    /// prove that x, where:
    /// ```
    /// x = keccak(
    ///          keccak(
    ///              keccak(hashOfOutput[:8]),
    ///              keccak(hashOfOutput[8:16])
    ///          ),
    ///          keccak(
    ///              keccak(hashOfOutput[16:24]),
    ///              keccak(hashOfOutput[24:])
    ///          )
    ///     )
    /// ```
    /// is contained in it. We can't simply use the output hash, because the
    /// size of the leaf is 8 bytes, not 32.
    function isOutputHashesRootHashValid(
        OutputValidityProof calldata v,
        bytes calldata output
    ) internal pure returns (bool) {
        return
            v.outputHashesRootHash ==
            MerkleV2.getRootAfterReplacementInDrive(
                CanonicalMachine.getIntraMemoryRangePosition(
                    v.outputIndexWithinInput,
                    CanonicalMachine.KECCAK_LOG2_SIZE
                ),
                CanonicalMachine.KECCAK_LOG2_SIZE.uint64OfSize(),
                CanonicalMachine.OUTPUT_METADATA_LOG2_SIZE.uint64OfSize(),
                MerkleV2.getMerkleRootFromBytes(
                    abi.encode(keccak256(abi.encode(output))),
                    CanonicalMachine.KECCAK_LOG2_SIZE.uint64OfSize()
                ),
                v.outputHashInOutputHashesSiblings
            );
    }

    /// @notice Calculate the input index
    /// @param v The output validity proof
    /// @return The input index
    function calculateInputIndex(
        OutputValidityProof calldata v
    ) internal pure returns (uint256) {
        return uint256(v.inputRange.firstIndex) + v.inputIndexWithinEpoch;
    }
}
