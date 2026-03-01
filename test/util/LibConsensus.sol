// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {IConsensus} from "src/consensus/IConsensus.sol";

import {Claim} from "./Claim.sol";

library LibConsensus {
    function submitClaim(IConsensus consensus, Claim memory claim) internal {
        consensus.submitClaim(
            claim.appContract, claim.lastProcessedBlockNumber, claim.outputsMerkleRoot
        );
    }

    function isOutputsMerkleRootValid(IConsensus consensus, Claim memory claim)
        internal
        view
        returns (bool)
    {
        return consensus.isOutputsMerkleRootValid(
            claim.appContract, claim.outputsMerkleRoot
        );
    }
}
