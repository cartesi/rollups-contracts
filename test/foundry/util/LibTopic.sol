// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

library LibTopic {
    /// @notice Convert address to log topic
    /// @param addr The address
    /// @return The address encoded as a log topic
    function asTopic(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }
}
