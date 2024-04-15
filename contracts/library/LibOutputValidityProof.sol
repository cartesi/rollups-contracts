// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {CanonicalMachine} from "../common/CanonicalMachine.sol";
import {Outputs} from "../common/Outputs.sol";
import {OutputValidityProof} from "../common/OutputValidityProof.sol";

import {LibMerkle32} from "./LibMerkle32.sol";

library LibOutputValidityProof {
    using LibMerkle32 for bytes32[];

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
        bytes32[] calldata siblings = v.outputHashesInEpochSiblings;
        return
            (siblings.length == CanonicalMachine.LOG2_MAX_INPUTS_PER_EPOCH) &&
            (v.outputsEpochRootHash ==
                siblings.merkleRootAfterReplacement(
                    v.inputIndexWithinEpoch,
                    v.outputHashesRootHash
                ));
    }

    /// @notice Check if the output hashes root hash is valid
    /// @param v The output validity proof
    /// @param outputHash The output hash
    function isOutputHashesRootHashValid(
        OutputValidityProof calldata v,
        bytes32 outputHash
    ) internal pure returns (bool) {
        bytes32[] calldata siblings = v.outputHashInOutputHashesSiblings;
        return
            (siblings.length == CanonicalMachine.LOG2_MAX_OUTPUTS_PER_INPUT) &&
            (v.outputHashesRootHash ==
                siblings.merkleRootAfterReplacement(
                    v.outputIndexWithinInput,
                    outputHash
                ));
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
