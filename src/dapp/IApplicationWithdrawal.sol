// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IWithdrawalOutputBuilder} from "../withdrawal/IWithdrawalOutputBuilder.sol";

interface IApplicationWithdrawal {
    // Events

    /// @notice MUST trigger when the funds of an account are withdrawn.
    /// @param accountIndex The account index in the accounts drive
    /// @param account The account as encoded in the accounts drive
    /// @param account The withdrawal output
    event Withdrawal(uint64 accountIndex, bytes account, bytes output);

    // View Functions

    /// @notice Get the log (base 2) of the number of leaves
    /// in the machine state tree that are reserved for
    /// each account in the accounts drive.
    function getLog2LeavesPerAccount() external view returns (uint8);

    /// @notice Get the log (base 2) of the maximum number
    /// of accounts that can be stored in the accounts drive.
    /// @notice This is equivalent to the depth of the accounts
    /// drive tree whose leaves are the account roots.
    function getLog2MaxNumOfAccounts() external view returns (uint8);

    /// @notice Get the factor that, when multiplied by the
    /// size of the accounts drive, yields the start memory address
    /// of the accounts drive.
    /// @dev If `a = getLog2LeavesPerAccount()`
    /// `b = getLog2MaxNumOfAccounts()`,
    /// and `c = getAccountsDriveStartIndex()`,
    /// then the accounts drive starts at `c*2^{a+b+5}`
    /// and has size `2^{a+b+5}`.
    function getAccountsDriveStartIndex() external view returns (uint64);

    /// @notice Get the withdrawal output builder, which gets static-called
    /// whenever the funds of an account are to be withdrawn.
    function getWithdrawalOutputBuilder() external view returns (IWithdrawalOutputBuilder);
}
