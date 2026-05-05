// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

/// @notice A delegate-call voucher
/// @param destination The destination address
/// @param payload The delegate-call payload
struct DelegateCallVoucher {
    address destination;
    bytes payload;
}
