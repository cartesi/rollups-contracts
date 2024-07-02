// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

/// @notice Proof of inclusion of an output in the output Merkle tree.
/// @param outputIndex Index of output in the Merkle tree
/// @param outputHashesSiblings Siblings of the output in the Merkle tree
/// @dev From the index and siblings, one can calculate the root of the Merkle tree.
/// @dev The siblings array should have size equal to the log2 of the maximum number of outputs.
/// @dev See the `CanonicalMachine` library for constants.
struct OutputValidityProof {
    uint64 outputIndex;
    bytes32[] outputHashesSiblings;
}
