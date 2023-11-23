// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

/// @title Calldata Library
library LibCalldata {
    /// @notice Check if a given byte array starts with a given 4-byte word,
    /// and return whatever comes after it.
    /// @param payload a byte array with at least 4 bytes
    /// @param selector the expected first 4 bytes of the payload
    /// @dev This function reverts if the payload is shorter than 4 bytes or
    /// if it does not start with the given 4 bytes.
    function trimSelector(
        bytes calldata payload,
        bytes4 selector
    ) internal pure returns (bytes calldata) {
        require(payload.length >= 4, "LibCalldata: payload too short");
        require(
            bytes4(payload[:4]) == selector,
            "LibCalldata: selector mismatch"
        );
        return payload[4:];
    }
}
