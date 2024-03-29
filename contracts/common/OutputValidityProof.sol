// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {InputRange} from "./InputRange.sol";

/// @param inputRange The range of inputs accepted during the epoch
/// @param inputIndexWithinEpoch Which input, inside the epoch, the output belongs to
/// @param outputIndexWithinInput Index of output emitted by the input
/// @param outputHashesRootHash Merkle root of hashes of outputs emitted by the input
/// @param outputsEpochRootHash Merkle root of all epoch's outputs metadata hashes
/// @param machineStateHash Hash of the machine state claimed this epoch
/// @param outputHashInOutputHashesSiblings Proof that this output metadata is in metadata memory range
/// @param outputHashesInEpochSiblings Proof that this output metadata is in epoch's output memory range
struct OutputValidityProof {
    InputRange inputRange;
    uint64 inputIndexWithinEpoch;
    uint64 outputIndexWithinInput;
    bytes32 outputHashesRootHash;
    bytes32 outputsEpochRootHash;
    bytes32 machineStateHash;
    bytes32[] outputHashInOutputHashesSiblings;
    bytes32[] outputHashesInEpochSiblings;
}
