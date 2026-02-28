// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Test} from "forge-std-1.9.6/src/Test.sol";

import {LibMath} from "./LibMath.sol";

contract LibMathTest is Test {
    function testMin(uint256 a, uint256 b) external pure {
        uint256 c = LibMath.min(a, b);
        assertTrue(c == a || c == b, "min(a, b) \\in {a, b}");
        assertLe(c, a);
        assertLe(c, b);
    }
}
