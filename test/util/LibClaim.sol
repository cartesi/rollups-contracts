// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {CanonicalMachine} from "src/common/CanonicalMachine.sol";
import {LibBinaryMerkleTree} from "src/library/LibBinaryMerkleTree.sol";
import {LibKeccak256} from "src/library/LibKeccak256.sol";

import {Claim} from "./Claim.sol";

library LibClaim {
    using LibBinaryMerkleTree for bytes32[];

    function computeMachineMerkleRoot(Claim calldata claim)
        external
        pure
        returns (bytes32 machineMerkleRoot)
    {
        machineMerkleRoot = claim.proof
            .merkleRootAfterReplacement(
                CanonicalMachine.TX_BUFFER_START >> CanonicalMachine.LOG2_DATA_BLOCK_SIZE,
                keccak256(abi.encode(claim.outputsMerkleRoot)),
                LibKeccak256.hashPair
            );
    }
}
