// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

interface IWithdrawalOutputBuilderErrors {
    /// @notice This error is raised whenever a user provides an account
    /// too short for the builder to decode. The error is accompanied by
    /// the minimum expected account size suitable for on-chain decoding.
    /// @param minAccountSize The minimum expected account size, in bytes.
    error AccountTooShort(uint64 minAccountSize);
}
