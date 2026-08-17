// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {MachineValidityProof} from "../../src/common/MachineValidityProof.sol";

struct Claim {
    address appContract;
    uint256 lastProcessedBlockNumber;
    bytes32 machineMerkleRoot;
    MachineValidityProof proof;
}
