// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title A Simple Consensus Contract
pragma solidity ^0.8.8;

import {AbstractConsensus} from "contracts/consensus/AbstractConsensus.sol";
import {InputRange} from "contracts/common/InputRange.sol";

contract SimpleConsensus is AbstractConsensus {
    function submitClaim(
        address,
        InputRange calldata,
        bytes32
    ) external pure override {
        revert("SimpleConsensus: cannot submit claim");
    }
}
