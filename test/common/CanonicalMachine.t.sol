// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {Test} from "forge-std-1.9.6/src/Test.sol";
import {CanonicalMachine} from "src/common/CanonicalMachine.sol";

import {EvmAdvanceEncoder} from "../util/EvmAdvanceEncoder.sol";

contract CanonicalMachineTest is Test {
    function testInputConstants() external view {
        assertLe(
            EvmAdvanceEncoder.encode(0, address(0), address(0), 0, new bytes(0)).length,
            CanonicalMachine.INPUT_MAX_SIZE,
            "The smallest input should be within the size limits"
        );
    }

    function testMemoryConstants() external pure {
        assertLt(
            CanonicalMachine.LOG2_MEMORY_SIZE,
            256,
            "Cannot represent 2^256 or larger numbers in an EVM word"
        );
        assertLe(
            CanonicalMachine.INPUT_MAX_SIZE,
            1 << CanonicalMachine.LOG2_MEMORY_SIZE,
            "Cannot fit an input inside the machine memory"
        );
    }

    function testMerkleTreeConstants() external pure {
        assertLe(
            CanonicalMachine.LOG2_DATA_BLOCK_SIZE,
            CanonicalMachine.LOG2_MEMORY_SIZE,
            "Data block is larger than the whole machine memory"
        );
    }
}
