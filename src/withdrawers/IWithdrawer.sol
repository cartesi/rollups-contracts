// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

interface IWithdrawer {
    /// @notice Withdraw the funds of an account.
    /// The encoding of accounts is application-specific.
    /// This function will be called via `delegatecall`,
    /// so it should not attempt to access its storage space.
    /// @param account The account
    /// @return accountOwner The account owner
    function withdraw(bytes calldata account) external returns (address accountOwner);
}
