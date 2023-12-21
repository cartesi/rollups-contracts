// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

library LibBytes {
    /// @notice Generate an address from a byte array.
    /// @param data The byte array
    /// @return The address
    function hashToAddress(bytes memory data) internal pure returns (address) {
        return address(bytes20(keccak256(data)));
    }

    /// @notice Generate a 256-bit unsigned integer from a byte array.
    /// @param data The byte array
    /// @return The 256-bit unsigned integer
    function hashToUint256(bytes memory data) internal pure returns (uint256) {
        return uint256(keccak256(data));
    }
}
