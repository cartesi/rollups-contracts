// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {OutputValidityProof} from "./OutputValidityProof.sol";
import {InputRange} from "./InputRange.sol";

/// @notice Data for validating outputs.
/// @param validity A validity proof for the output
/// @param inputRange The range of inputs accepted during the epoch
struct Proof {
    OutputValidityProof validity;
    InputRange inputRange;
}
