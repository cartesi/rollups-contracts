// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {CanonicalMachine} from "../common/CanonicalMachine.sol";
import {OutputValidityProof} from "../common/OutputValidityProof.sol";

import {LibHash} from "./LibHash.sol";
import {LibBinaryMerkleTree} from "./LibBinaryMerkleTree.sol";

library LibOutputValidityProof {
    using LibBinaryMerkleTree for bytes32[];

    function isSiblingsArrayLengthValid(OutputValidityProof calldata v)
        internal
        pure
        returns (bool)
    {
        return v.outputHashesSiblings.length == CanonicalMachine.LOG2_MAX_OUTPUTS;
    }

    function computeOutputsMerkleRoot(OutputValidityProof calldata v, bytes32 outputHash)
        internal
        pure
        returns (bytes32)
    {
        return v.outputHashesSiblings.merkleRootAfterReplacement(
            v.outputIndex, outputHash, LibHash.efficientKeccak256
        );
    }
}
