// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {CanonicalMachine} from "../common/CanonicalMachine.sol";
import {IApplication} from "../dapp/IApplication.sol";
import {MerkleV2} from "@cartesi/util/contracts/MerkleV2.sol";
import {Outputs} from "../common/Outputs.sol";
import {OutputValidityProof} from "../common/OutputValidityProof.sol";

/// @title Output Validation Library
library LibOutputValidation {
    using CanonicalMachine for CanonicalMachine.Log2Size;

    /// @notice Make sure the output proof is valid, otherwise revert.
    /// @param v The output validity proof
    /// @param encodedOutput The encoded output
    /// @param epochHash The hash of the epoch in which the output was generated
    function validateEncodedOutput(
        OutputValidityProof calldata v,
        bytes memory encodedOutput,
        bytes32 epochHash
    ) internal pure {
        // prove that outputs hash is represented in a finalized epoch
        if (
            keccak256(
                abi.encodePacked(v.outputsEpochRootHash, v.machineStateHash)
            ) != epochHash
        ) {
            revert IApplication.IncorrectEpochHash();
        }

        // prove that output metadata memory range is contained in epoch's output memory range
        if (
            MerkleV2.getRootAfterReplacementInDrive(
                CanonicalMachine.getIntraMemoryRangePosition(
                    v.inputIndexWithinEpoch,
                    CanonicalMachine.KECCAK_LOG2_SIZE
                ),
                CanonicalMachine.KECCAK_LOG2_SIZE.uint64OfSize(),
                CanonicalMachine.EPOCH_OUTPUT_LOG2_SIZE.uint64OfSize(),
                v.outputHashesRootHash,
                v.outputHashesInEpochSiblings
            ) != v.outputsEpochRootHash
        ) {
            revert IApplication.IncorrectOutputsEpochRootHash();
        }

        // The hash of the output is converted to bytes (abi.encode) and
        // treated as data. The metadata output memory range stores that data while
        // being indifferent to its contents. To prove that the received
        // output is contained in the metadata output memory range we need to
        // prove that x, where:
        // x = keccak(
        //          keccak(
        //              keccak(hashOfOutput[0:7]),
        //              keccak(hashOfOutput[8:15])
        //          ),
        //          keccak(
        //              keccak(hashOfOutput[16:23]),
        //              keccak(hashOfOutput[24:31])
        //          )
        //     )
        // is contained in it. We can't simply use hashOfOutput because the
        // log2size of the leaf is three (8 bytes) not  five (32 bytes)
        bytes32 merkleRootOfHashOfOutput = MerkleV2.getMerkleRootFromBytes(
            abi.encodePacked(keccak256(abi.encode(encodedOutput))),
            CanonicalMachine.KECCAK_LOG2_SIZE.uint64OfSize()
        );

        // prove that Merkle root of bytes(hashOfOutput) is contained
        // in the output metadata array memory range
        if (
            MerkleV2.getRootAfterReplacementInDrive(
                CanonicalMachine.getIntraMemoryRangePosition(
                    v.outputIndexWithinInput,
                    CanonicalMachine.KECCAK_LOG2_SIZE
                ),
                CanonicalMachine.KECCAK_LOG2_SIZE.uint64OfSize(),
                CanonicalMachine.OUTPUT_METADATA_LOG2_SIZE.uint64OfSize(),
                merkleRootOfHashOfOutput,
                v.outputHashInOutputHashesSiblings
            ) != v.outputHashesRootHash
        ) {
            revert IApplication.IncorrectOutputHashesRootHash();
        }
    }

    /// @notice Make sure the output proof is valid, otherwise revert.
    /// @param v The output validity proof
    /// @param destination The address that will receive the payload through a message call
    /// @param payload The payload, which—in the case of Solidity contracts—encodes a function call
    /// @param epochHash The hash of the epoch in which the output was generated
    function validateVoucher(
        OutputValidityProof calldata v,
        address destination,
        bytes calldata payload,
        bytes32 epochHash
    ) internal pure {
        validateEncodedOutput(
            v,
            abi.encodeCall(Outputs.Voucher, (destination, payload)),
            epochHash
        );
    }

    /// @notice Make sure the output proof is valid, otherwise revert.
    /// @param v The output validity proof
    /// @param notice The notice
    /// @param epochHash The hash of the epoch in which the output was generated
    function validateNotice(
        OutputValidityProof calldata v,
        bytes calldata notice,
        bytes32 epochHash
    ) internal pure {
        validateEncodedOutput(
            v,
            abi.encodeCall(Outputs.Notice, (notice)),
            epochHash
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
