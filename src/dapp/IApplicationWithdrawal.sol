// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {AccountValidityProof} from "../common/AccountValidityProof.sol";
import {IWithdrawalOutputBuilder} from "../withdrawal/IWithdrawalOutputBuilder.sol";

interface IApplicationWithdrawal {
    // Events

    /// @notice MUST trigger when the funds of an account are withdrawn.
    /// @param accountIndex The account index in the accounts drive
    /// @param account The account as encoded in the accounts drive
    /// @param account The withdrawal output
    event Withdrawal(uint64 accountIndex, bytes account, bytes output);

    // Errors

    /// @notice Raised when the account root siblings array has an invalid length.
    /// @dev The array length should be log2 of the machine memory size -
    /// log2 of the data block size - log2 of the maximum number of accounts.
    /// See the `CanonicalMachine` library for machine constants
    /// and the `getLog2MaxNumOfAccounts` function for accounts drive parameters.
    error InvalidAccountRootSiblingsArrayLength();

    /// @notice Raised when the account index is outside the accounts drive boundaries.
    /// See the `getLog2MaxNumOfAccounts` for accounts drive parameters.
    error InvalidAccountIndex();

    /// @notice Raised when the computed machine Merkle root differs
    /// from the one provided by the current outputs Merkle root validator.
    error InvalidMachineMerkleRoot(bytes32 machineMerkleRoot);

    // View Functions

    /// @notice Get the number of withdrawals.
    /// Useful for fast-syncing `Withdrawal` events.
    function getNumberOfWithdrawals() external view returns (uint256);

    /// @notice Check whether an account had its funds withdrawn.
    /// @param accountIndex The index of the account in the accounts drive.
    function wereAccountFundsWithdrawn(uint256 accountIndex) external view returns (bool);

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

    /// @notice Validate the existence of an account at a given index
    /// on the accounts drive given a Merkle proof of the account root,
    /// according to the last finalized machine Merkle root reported by
    /// the application outputs Merkle root validator.
    /// @param accountMerkleRoot The account Merkle root
    /// @param proof The proof used to validate the account
    /// @dev May raise `InvalidAccountRootSiblingsArrayLength`,
    /// `InvalidAccountIndex`, or `InvalidMachineMerkleRoot`.
    function validateAccountMerkleRoot(
        bytes32 accountMerkleRoot,
        AccountValidityProof calldata proof
    ) external view;
}
