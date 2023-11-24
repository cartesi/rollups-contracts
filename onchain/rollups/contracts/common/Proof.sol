// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {OutputValidityProof} from "./OutputValidityProof.sol";

/// @notice Data for validating outputs.
/// @param validity A validity proof for the output
/// @param context Data for querying the right claim from the current consensus contract
/// @dev The encoding of `context` might vary depending on the implementation of the consensus contract.
struct Proof {
    OutputValidityProof validity;
    bytes context;
}
