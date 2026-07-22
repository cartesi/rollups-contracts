// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {LeafProof} from "./LeafProof.sol";

/// @notice Contains information used to prove the validity of a post-epoch machine state
/// (yielded manually with an 'rx accepted' reason) and its outputs Merkle root (stored
/// at the start of the tx buffer).
/// @param iflagsYProof Proves the iflags_Y register
/// @param htifTohostProof Proves the HTIF tohost register
/// @param txBufferProof Proves the first data block of the CMIO tx buffer
struct MachineValidityProof {
    LeafProof iflagsYProof;
    LeafProof htifTohostProof;
    LeafProof txBufferProof;
}
