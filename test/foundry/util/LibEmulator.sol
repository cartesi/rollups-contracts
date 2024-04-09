// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {CanonicalMachine} from "contracts/common/CanonicalMachine.sol";
import {OutputValidityProof} from "contracts/common/OutputValidityProof.sol";
import {InputRange} from "contracts/common/InputRange.sol";
import {LibMerkle32} from "contracts/library/LibMerkle32.sol";

library LibEmulator {
    using SafeCast for uint256;
    using LibMerkle32 for bytes32[];
    using LibEmulator for LibEmulator.State;

    struct State {
        uint256 epochCount;
        mapping(uint256 => uint64) inputCount;
        mapping(uint256 => bytes32) machineStateHashes;
        mapping(uint256 => mapping(uint256 => bytes[])) outputs;
    }

    struct OutputId {
        uint256 epochIndex;
        uint64 inputIndexWithinEpoch;
        uint64 outputIndexWithinInput;
    }

    // -------------
    // state changes
    // -------------

    function addOutput(
        State storage state,
        bytes memory output
    ) internal returns (OutputId memory oid) {
        bytes[] storage outputs;
        oid.epochIndex = state.epochCount;
        oid.inputIndexWithinEpoch = state.inputCount[oid.epochIndex];
        outputs = state.outputs[oid.epochIndex][oid.inputIndexWithinEpoch];
        oid.outputIndexWithinInput = outputs.length.toUint64();
        outputs.push(output);
    }

    function finishInput(State storage state) internal {
        uint256 epochIndex = state.epochCount;
        ++state.inputCount[epochIndex];
    }

    function finishEpoch(
        State storage state,
        bytes32 machineStateHash
    ) internal {
        uint256 epochIndex = state.epochCount;
        require(
            state.inputCount[epochIndex] > 0,
            "LibEmulator: cannot finish epoch with zero inputs"
        );
        state.machineStateHashes[epochIndex] = machineStateHash;
        ++state.epochCount;
    }

    // -------------
    // state queries
    // -------------

    function getOutput(
        State storage state,
        OutputId memory oid
    ) internal view returns (bytes storage) {
        // prettier-ignore
        return
            state.outputs
                [oid.epochIndex]
                [oid.inputIndexWithinEpoch]
                [oid.outputIndexWithinInput];
    }

    function getOutputs(
        State storage state,
        uint256 epochIndex,
        uint64 inputIndexWithinEpoch
    ) internal view returns (bytes[] storage) {
        return state.outputs[epochIndex][inputIndexWithinEpoch];
    }

    function getMachineStateHash(
        State storage state,
        uint256 epochIndex
    ) internal view returns (bytes32) {
        return state.machineStateHashes[epochIndex];
    }

    function getOutputValidityProof(
        State storage state,
        OutputId memory oid
    ) internal view returns (OutputValidityProof memory) {
        bytes[] memory outputs;
        bytes32[] memory outputHashes;
        bytes32[] memory outputHashInOutputHashesSiblings;
        bytes32[] memory outputHashesInEpoch;
        bytes32[] memory outputHashesInEpochSiblings;

        outputs = state.getOutputs(oid.epochIndex, oid.inputIndexWithinEpoch);

        outputHashes = getOutputHashes(outputs);

        outputHashesInEpoch = state.getOutputHashesInEpoch(oid.epochIndex);

        outputHashInOutputHashesSiblings = getOutputHashInOutputHashesSiblings(
            outputHashes,
            oid.outputIndexWithinInput
        );

        outputHashesInEpochSiblings = getOutputHashesInEpochSiblings(
            outputHashesInEpoch,
            oid.inputIndexWithinEpoch
        );

        return
            OutputValidityProof(
                state.getInputRange(oid.epochIndex),
                oid.inputIndexWithinEpoch,
                oid.outputIndexWithinInput,
                getOutputHashesRootHash(outputHashes),
                getOutputsEpochRootHash(outputHashesInEpoch),
                state.getMachineStateHash(oid.epochIndex),
                outputHashInOutputHashesSiblings,
                outputHashesInEpochSiblings
            );
    }

    function getInputRange(
        State storage state,
        uint256 epochIndex
    ) internal view returns (InputRange memory r) {
        for (uint256 i; i < epochIndex; ++i) {
            r.firstIndex += state.inputCount[i];
        }
        r.lastIndex = r.firstIndex + state.inputCount[epochIndex] - 1;
    }

    function getEpochHash(
        State storage state,
        uint256 epochIndex
    ) internal view returns (bytes32) {
        bytes32[] memory outputHashesInEpoch;
        outputHashesInEpoch = state.getOutputHashesInEpoch(epochIndex);
        return
            keccak256(
                abi.encode(
                    getOutputsEpochRootHash(outputHashesInEpoch),
                    state.machineStateHashes[epochIndex]
                )
            );
    }

    // ----------------
    // outputs in epoch
    // ----------------

    function getOutputsEpochRootHash(
        bytes32[] memory outputHashesInEpoch
    ) internal pure returns (bytes32) {
        return
            outputHashesInEpoch.merkleRoot(
                CanonicalMachine.LOG2_MAX_INPUTS_PER_EPOCH
            );
    }

    function getOutputHashesInEpochSiblings(
        bytes32[] memory outputHashesInEpoch,
        uint64 inputIndexWithinEpoch
    ) internal pure returns (bytes32[] memory) {
        return
            outputHashesInEpoch.siblings(
                inputIndexWithinEpoch,
                CanonicalMachine.LOG2_MAX_INPUTS_PER_EPOCH
            );
    }

    function getOutputHashesInEpoch(
        State storage state,
        uint256 epochIndex
    ) internal view returns (bytes32[] memory leaves) {
        leaves = new bytes32[](state.inputCount[epochIndex]);
        for (uint64 i; i < leaves.length; ++i) {
            bytes[] memory outputs;
            bytes32[] memory outputHashes;
            outputs = state.getOutputs(epochIndex, i);
            outputHashes = getOutputHashes(outputs);
            leaves[i] = getOutputHashesRootHash(outputHashes);
        }
    }

    // ----------------
    // outputs in input
    // ----------------

    function getOutputHashesRootHash(
        bytes32[] memory outputHashes
    ) internal pure returns (bytes32) {
        return
            outputHashes.merkleRoot(
                CanonicalMachine.LOG2_MAX_OUTPUTS_PER_INPUT
            );
    }

    function getOutputHashInOutputHashesSiblings(
        bytes32[] memory outputHashes,
        uint64 outputIndexWithinInput
    ) internal pure returns (bytes32[] memory) {
        return
            outputHashes.siblings(
                outputIndexWithinInput,
                CanonicalMachine.LOG2_MAX_OUTPUTS_PER_INPUT
            );
    }

    function getOutputHashes(
        bytes[] memory outputs
    ) internal pure returns (bytes32[] memory leaves) {
        leaves = new bytes32[](outputs.length);
        for (uint256 i; i < leaves.length; ++i) {
            leaves[i] = keccak256(outputs[i]);
        }
    }
}
