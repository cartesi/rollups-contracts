// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

/// @param inputIndexWithinEpoch Which input, inside the epoch, the output belongs to
/// @param outputIndexWithinInput Index of output emitted by the input
/// @param outputHashesRootHash Merkle root of hashes of outputs emitted by the input
/// @param vouchersEpochRootHash Merkle root of all epoch's voucher metadata hashes
/// @param noticesEpochRootHash Merkle root of all epoch's notice metadata hashes
/// @param machineStateHash Hash of the machine state claimed this epoch
/// @param outputHashInOutputHashesSiblings Proof that this output metadata is in metadata memory range
/// @param outputHashesInEpochSiblings Proof that this output metadata is in epoch's output memory range
struct OutputValidityProof {
    uint64 inputIndexWithinEpoch;
    uint64 outputIndexWithinInput;
    bytes32 outputHashesRootHash;
    bytes32 vouchersEpochRootHash;
    bytes32 noticesEpochRootHash;
    bytes32 machineStateHash;
    bytes32[] outputHashInOutputHashesSiblings;
    bytes32[] outputHashesInEpochSiblings;
}
