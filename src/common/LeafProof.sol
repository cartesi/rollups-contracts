// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

/// @notice Proves a data block at a known offset in the machine.
/// @param dataBlock The 32-byte data block at the known offset
/// @param siblings The bottom-up siblings of the leaf node
struct LeafProof {
    bytes32 dataBlock;
    bytes32[] siblings;
}
