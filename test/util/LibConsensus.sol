// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {IConsensus} from "src/consensus/IConsensus.sol";

import {Claim} from "./Claim.sol";

library LibConsensus {
    function submitClaim(IConsensus consensus, Claim memory claim) internal {
        consensus.submitClaim(
            claim.appContract,
            claim.lastProcessedBlockNumber,
            claim.machineMerkleRoot,
            claim.proof
        );
    }

    function getClaim(IConsensus consensus, Claim memory claim)
        internal
        view
        returns (IConsensus.Claim memory stagedClaimInfo)
    {
        return consensus.getClaim(
            claim.appContract, claim.lastProcessedBlockNumber, claim.machineMerkleRoot
        );
    }

    function acceptClaim(IConsensus consensus, Claim memory claim) internal {
        consensus.acceptClaim(
            claim.appContract, claim.lastProcessedBlockNumber, claim.machineMerkleRoot
        );
    }

    function isOutputsMerkleRootValid(IConsensus consensus, Claim memory claim)
        internal
        view
        returns (bool)
    {
        bytes32 outputsMerkleRoot = claim.proof.txBufferProof.dataBlock;
        return consensus.isOutputsMerkleRootValid(claim.appContract, outputsMerkleRoot);
    }
}
