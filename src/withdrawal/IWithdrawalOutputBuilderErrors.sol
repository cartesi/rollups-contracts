// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

interface IWithdrawalOutputBuilderErrors {
    /// @notice This error is raised whenever a user provides an ill-sized
    /// account for the builder to decode. The error is accompanied by
    /// the size of the account whose funds were attempted to be withdrawn
    /// and the expected account size suitable for on-chain decoding.
    /// @param attemptedAccountSize The attempted account size, in bytes.
    /// @param accountSize The expected account size, in bytes.
    error InvalidAccountSize(uint256 attemptedAccountSize, uint64 accountSize);
}
