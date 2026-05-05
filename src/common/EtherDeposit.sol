// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

/// @notice An Ether token deposit
/// @param sender The Ether sender
/// @param value The Ether amount (in Wei)
struct EtherDeposit {
    address sender;
    uint256 value;
}
