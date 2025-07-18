// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {SafeCast} from "@openzeppelin-contracts-5.2.0/utils/math/SafeCast.sol";

import {CanonicalMachine} from "src/common/CanonicalMachine.sol";
import {OutputValidityProof} from "src/common/OutputValidityProof.sol";
import {LibKeccak256} from "src/library/LibKeccak256.sol";

import {LibBinaryMerkleTreeHelper} from "./LibBinaryMerkleTreeHelper.sol";

library LibEmulator {
    using SafeCast for uint256;
    using LibEmulator for State;
    using LibBinaryMerkleTreeHelper for bytes[];
    using LibBinaryMerkleTreeHelper for bytes32[];

    struct State {
        bytes[] outputs;
    }

    bytes32 constant NO_OUTPUT_SENTINEL_VALUE = bytes32(0);

    // -------------
    // state changes
    // -------------

    function addOutput(State storage state, bytes memory output)
        internal
        returns (uint64 outputIndex)
    {
        bytes[] storage outputs = state.outputs;
        outputIndex = outputs.length.toUint64();
        outputs.push(output);
    }

    // -------------
    // state queries
    // -------------

    function getOutput(State storage state, uint64 outputIndex)
        internal
        view
        returns (bytes storage output)
    {
        return state.outputs[outputIndex];
    }

    function getOutputValidityProof(State storage state, uint64 outputIndex)
        internal
        view
        returns (OutputValidityProof memory proof)
    {
        return OutputValidityProof({
            outputIndex: outputIndex,
            outputHashesSiblings: state.getOutpuHashesSiblings(outputIndex)
        });
    }

    function getOutputsMerkleRoot(State storage state)
        internal
        view
        returns (bytes32 outputsMerkleRoot)
    {
        return state.getOutputHashes().merkleRootFromNodes(
            NO_OUTPUT_SENTINEL_VALUE,
            CanonicalMachine.LOG2_MAX_OUTPUTS,
            LibKeccak256.hashPair
        );
    }

    function getOutpuHashesSiblings(State storage state, uint64 outputIndex)
        internal
        view
        returns (bytes32[] memory outputHashSiblings)
    {
        return state.getOutputHashes().siblings(
            NO_OUTPUT_SENTINEL_VALUE,
            outputIndex,
            CanonicalMachine.LOG2_MAX_OUTPUTS,
            LibKeccak256.hashPair
        );
    }

    function getOutputHashes(State storage state)
        internal
        view
        returns (bytes32[] memory outputHashes)
    {
        return state.outputs.toLeaves(LibKeccak256.hashBytes);
    }
}
