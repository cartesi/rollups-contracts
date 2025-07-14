// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {SafeCast} from "@openzeppelin-contracts-5.2.0/utils/math/SafeCast.sol";

import {CanonicalMachine} from "src/common/CanonicalMachine.sol";
import {OutputValidityProof} from "src/common/OutputValidityProof.sol";
import {LibHash} from "src/library/LibHash.sol";

import {LibBinaryMerkleTreeHelper} from "./LibBinaryMerkleTreeHelper.sol";

library LibEmulator {
    using SafeCast for uint256;
    using LibBinaryMerkleTreeHelper for bytes32[];

    struct State {
        bytes[] outputs;
    }

    bytes32 constant NO_OUTPUT_LEAF_NODE = bytes32(0);

    type OutputIndex is uint64;

    // -------------
    // state changes
    // -------------

    function addOutput(State storage state, bytes memory output)
        internal
        returns (OutputIndex outputIndex)
    {
        bytes[] storage outputs = state.outputs;
        outputIndex = OutputIndex.wrap(outputs.length.toUint64());
        outputs.push(output);
    }

    // -------------
    // state queries
    // -------------

    function getOutput(State storage state, OutputIndex outputIndex)
        internal
        view
        returns (bytes storage)
    {
        return state.outputs[OutputIndex.unwrap(outputIndex)];
    }

    function getOutputValidityProof(State storage state, OutputIndex outputIndex)
        internal
        view
        returns (OutputValidityProof memory)
    {
        bytes32[] memory outputHashes;

        outputHashes = getOutputHashes(state.outputs);

        return OutputValidityProof(
            OutputIndex.unwrap(outputIndex),
            getOutputSiblings(outputHashes, OutputIndex.unwrap(outputIndex))
        );
    }

    function getOutputsMerkleRoot(State storage state) internal view returns (bytes32) {
        bytes32[] memory outputHashes;

        outputHashes = getOutputHashes(state.outputs);

        return getOutputsMerkleRoot(outputHashes);
    }

    // -----------------
    // Merkle operations
    // -----------------

    function getOutputsMerkleRoot(bytes32[] memory outputHashes)
        internal
        pure
        returns (bytes32)
    {
        return outputHashes.merkleRootFromNodes(
            NO_OUTPUT_LEAF_NODE,
            CanonicalMachine.LOG2_MAX_OUTPUTS,
            LibHash.efficientKeccak256
        );
    }

    function getOutputSiblings(bytes32[] memory outputHashes, uint64 outputIndex)
        internal
        pure
        returns (bytes32[] memory)
    {
        return outputHashes.siblings(
            NO_OUTPUT_LEAF_NODE,
            outputIndex,
            CanonicalMachine.LOG2_MAX_OUTPUTS,
            LibHash.efficientKeccak256
        );
    }

    // ---------------
    // Hash operations
    // ---------------

    function getOutputHashes(bytes[] memory outputs)
        internal
        pure
        returns (bytes32[] memory leaves)
    {
        leaves = new bytes32[](outputs.length);
        for (uint256 i; i < leaves.length; ++i) {
            leaves[i] = keccak256(outputs[i]);
        }
    }
}
