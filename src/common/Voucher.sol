// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

/// @notice A voucher
/// @param destination The destination address
/// @param value The Ether amount (in Wei)
/// @param payload The call payload
struct Voucher {
    address destination;
    uint256 value;
    bytes payload;
}
