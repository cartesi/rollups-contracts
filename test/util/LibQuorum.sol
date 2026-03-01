// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {IQuorum} from "src/consensus/quorum/IQuorum.sol";

import {Claim} from "./Claim.sol";

library LibQuorum {
    function numOfValidatorsInFavorOfAnyClaimInEpoch(IQuorum quorum, Claim memory claim)
        internal
        view
        returns (uint256)
    {
        return quorum.numOfValidatorsInFavorOfAnyClaimInEpoch(
            claim.appContract, claim.lastProcessedBlockNumber
        );
    }

    function isValidatorInFavorOfAnyClaimInEpoch(
        IQuorum quorum,
        Claim memory claim,
        uint256 id
    ) internal view returns (bool) {
        return quorum.isValidatorInFavorOfAnyClaimInEpoch(
            claim.appContract, claim.lastProcessedBlockNumber, id
        );
    }

    function numOfValidatorsInFavorOf(IQuorum quorum, Claim memory claim)
        internal
        view
        returns (uint256)
    {
        return quorum.numOfValidatorsInFavorOf(
            claim.appContract, claim.lastProcessedBlockNumber, claim.outputsMerkleRoot
        );
    }

    function isValidatorInFavorOf(IQuorum quorum, Claim memory claim, uint256 id)
        internal
        view
        returns (bool)
    {
        return quorum.isValidatorInFavorOf(
            claim.appContract, claim.lastProcessedBlockNumber, claim.outputsMerkleRoot, id
        );
    }
}
