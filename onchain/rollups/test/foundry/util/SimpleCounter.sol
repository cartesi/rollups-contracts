// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title A Simple Counter Contract
pragma solidity ^0.8.8;

contract SimpleCounter {
    uint256 counter;

    function inc() external {
        ++counter;
    }

    function get() external view returns (uint256) {
        return counter;
    }
}
