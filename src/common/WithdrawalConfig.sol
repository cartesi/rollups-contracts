// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IWithdrawalOutputBuilder} from "../withdrawal/IWithdrawalOutputBuilder.sol";

// @notice Withdrawal configuration parameters.
// @param guardian The address of the account with guardian priviledges
// @param log2LeavesPerAccount The base-2 log of leaves per account
// @param log2MaxNumOfAccounts The base-2 log of max. num. of accounts
// @param accountsDriveStartIndex The offset of the accounts drive
// @param withdrawalOutputBuilder The address of the withdrawal output builder
struct WithdrawalConfig {
    address guardian;
    uint8 log2LeavesPerAccount;
    uint8 log2MaxNumOfAccounts;
    uint64 accountsDriveStartIndex;
    IWithdrawalOutputBuilder withdrawalOutputBuilder;
}
