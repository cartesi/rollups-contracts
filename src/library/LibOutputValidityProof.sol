// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {CanonicalMachine} from "../common/CanonicalMachine.sol";
import {OutputValidityProof} from "../common/OutputValidityProof.sol";

import {LibMerkle32} from "./LibMerkle32.sol";

library LibOutputValidityProof {
    using LibMerkle32 for bytes32[];

    function isSiblingsArrayLengthValid(OutputValidityProof calldata v)
        internal
        pure
        returns (bool)
    {
        return
            v.outputHashesSiblings.length == CanonicalMachine.LOG2_MAX_OUTPUTS;
    }

    function computeOutputsMerkleRoot(
        OutputValidityProof calldata v,
        bytes32 outputHash
    ) internal pure returns (bytes32) {
        return v.outputHashesSiblings.merkleRootAfterReplacement(
            v.outputIndex, outputHash
        );
    }
}
