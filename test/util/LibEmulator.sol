// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {CanonicalMachine} from "contracts/common/CanonicalMachine.sol";
import {OutputValidityProof} from "contracts/common/OutputValidityProof.sol";
import {LibMerkle32} from "contracts/library/LibMerkle32.sol";

library LibEmulator {
    using SafeCast for uint256;
    using LibMerkle32 for bytes32[];

    struct State {
        bytes[] outputs;
    }

    type OutputIndex is uint64;

    // -------------
    // state changes
    // -------------

    function addOutput(
        State storage state,
        bytes memory output
    ) internal returns (OutputIndex outputIndex) {
        bytes[] storage outputs = state.outputs;
        outputIndex = OutputIndex.wrap(outputs.length.toUint64());
        outputs.push(output);
    }

    // -------------
    // state queries
    // -------------

    function getOutput(
        State storage state,
        OutputIndex outputIndex
    ) internal view returns (bytes storage) {
        return state.outputs[OutputIndex.unwrap(outputIndex)];
    }

    function getOutputValidityProof(
        State storage state,
        OutputIndex outputIndex
    ) internal view returns (OutputValidityProof memory) {
        bytes32[] memory outputHashes;

        outputHashes = getOutputHashes(state.outputs);

        return
            OutputValidityProof(
                OutputIndex.unwrap(outputIndex),
                getOutputHashesSiblings(
                    outputHashes,
                    OutputIndex.unwrap(outputIndex)
                )
            );
    }

    function getClaim(State storage state) internal view returns (bytes32) {
        bytes32[] memory outputHashes;

        outputHashes = getOutputHashes(state.outputs);

        return getOutputHashesRootHash(outputHashes);
    }

    // -----------------
    // Merkle operations
    // -----------------

    function getOutputHashesRootHash(
        bytes32[] memory outputHashes
    ) internal pure returns (bytes32) {
        return outputHashes.merkleRoot(CanonicalMachine.LOG2_MAX_OUTPUTS);
    }

    function getOutputHashesSiblings(
        bytes32[] memory outputHashes,
        uint64 outputIndex
    ) internal pure returns (bytes32[] memory) {
        return
            outputHashes.siblings(
                outputIndex,
                CanonicalMachine.LOG2_MAX_OUTPUTS
            );
    }

    // ---------------
    // Hash operations
    // ---------------

    function getOutputHashes(
        bytes[] memory outputs
    ) internal pure returns (bytes32[] memory leaves) {
        leaves = new bytes32[](outputs.length);
        for (uint256 i; i < leaves.length; ++i) {
            leaves[i] = keccak256(outputs[i]);
        }
    }
}
