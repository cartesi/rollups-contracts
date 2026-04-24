// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {AccountValidityProof} from "../common/AccountValidityProof.sol";
import {LibBinaryMerkleTree} from "./LibBinaryMerkleTree.sol";
import {LibKeccak256} from "./LibKeccak256.sol";

library LibAccountValidityProof {
    function isSiblingsArrayLengthValid(
        AccountValidityProof calldata v,
        uint8 log2MaxNumOfAccounts
    ) internal pure returns (bool) {
        return v.accountRootSiblings.length == log2MaxNumOfAccounts;
    }

    function computeAccountsDriveMerkleRoot(
        AccountValidityProof calldata v,
        bytes32 accountMerkleRoot
    ) internal pure returns (bytes32) {
        return LibBinaryMerkleTree.merkleRootAfterReplacement(
            v.accountRootSiblings,
            v.accountIndex,
            accountMerkleRoot,
            LibKeccak256.hashPair
        );
    }
}
