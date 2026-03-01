// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {
    EmulatorConstants
} from "cartesi-machine-solidity-step-0.13.0/src/EmulatorConstants.sol";

import {LibMerkle32} from "src/library/LibMerkle32.sol";

import {Claim} from "./Claim.sol";

library LibClaim {
    using LibMerkle32 for bytes32[];

    function computeMachineMerkleRoot(Claim calldata claim)
        external
        pure
        returns (bytes32 machineMerkleRoot)
    {
        machineMerkleRoot = claim.proof
            .merkleRootAfterReplacement(
                EmulatorConstants.PMA_CMIO_TX_BUFFER_START
                    >> EmulatorConstants.TREE_LOG2_WORD_SIZE,
                keccak256(abi.encode(claim.outputsMerkleRoot))
            );
    }
}
