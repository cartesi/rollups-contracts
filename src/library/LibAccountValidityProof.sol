// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {AccountValidityProof} from "../common/AccountValidityProof.sol";
import {CanonicalMachine} from "../common/CanonicalMachine.sol";
import {LibBinaryMerkleTree} from "./LibBinaryMerkleTree.sol";
import {LibKeccak256} from "./LibKeccak256.sol";

library LibAccountValidityProof {
    function isSiblingsArrayLengthValid(
        AccountValidityProof calldata v,
        uint8 log2LeavesPerAccount
    ) internal pure returns (bool) {
        // The addition below cannot overflow because
        /// `ceil(calldatasize / 32) + 2 * type(uint8).max <= type(uint256).max`.
        // (Considering the cost of tx calldata size, the tx gas cost would likely
        /// surpass the block gas limit.)
        return (v.accountRootSiblings.length + CanonicalMachine.LOG2_DATA_BLOCK_SIZE
                    + log2LeavesPerAccount) == CanonicalMachine.LOG2_MEMORY_SIZE;
    }

    function isAccountIndexValid(
        AccountValidityProof calldata v,
        uint8 log2MaxNumOfAccounts
    ) internal pure returns (bool) {
        // This is equivalent to `accountIndex < 2^{log2MaxNumOfAccounts}`,
        // and works with any value of `log2MaxNumOfAccounts`, even if
        // typed as `uint256`.
        return (v.accountIndex >> log2MaxNumOfAccounts) == 0;
    }

    function computeMachineMerkleRoot(
        AccountValidityProof calldata v,
        bytes32 accountMerkleRoot,
        uint8 log2MaxNumOfAccounts,
        uint64 accountsDriveStartIndex
    ) internal pure returns (bytes32) {
        bytes32 accountsDriveMerkleRoot =
            LibBinaryMerkleTree.merkleRootAfterReplacement(
                v.accountRootSiblings[:log2MaxNumOfAccounts],
                v.accountIndex,
                accountMerkleRoot,
                LibKeccak256.hashPair
            );

        return LibBinaryMerkleTree.merkleRootAfterReplacement(
            v.accountRootSiblings[log2MaxNumOfAccounts:],
            accountsDriveStartIndex,
            accountsDriveMerkleRoot,
            LibKeccak256.hashPair
        );
    }
}
