// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {AccountValidityProof} from "../common/AccountValidityProof.sol";
import {BinaryMerkleTreeErrors} from "../common/BinaryMerkleTreeErrors.sol";
import {IWithdrawalOutputBuilder} from "../withdrawal/IWithdrawalOutputBuilder.sol";
import {
    IWithdrawalOutputBuilderErrors
} from "../withdrawal/IWithdrawalOutputBuilderErrors.sol";

interface IApplicationWithdrawal is
    BinaryMerkleTreeErrors,
    IWithdrawalOutputBuilderErrors
{
    // Events

    /// @notice MUST trigger when the funds of an account are withdrawn.
    /// @param accountIndex The account index in the accounts drive
    /// @param account The account as encoded in the accounts drive
    /// @param output The withdrawal output
    event Withdrawal(uint64 accountIndex, bytes account, bytes output);

    // Errors

    /// @notice Raised when the application has not yet been foreclosed
    /// and therefore withdrawal-related actions cannot be performed yet.
    error NotForeclosed();

    /// @notice Raised when the accounts drive Merkle root proof size is invalid.
    /// @dev The array length should be log2 of the machine memory size - log2 of the
    /// accounts drive size. See the `CanonicalMachine` library and the
    /// `getLog2MaxNumOfAccounts` and `getLog2LeavesPerAccount` functions.
    error InvalidAccountsDriveMerkleRootProofSize();

    /// @notice Raised when someone tries to prove the accounts drive Merkle root but it
    /// has already been proved. This error adds an extra layer of protection against
    /// consensus-takeover attacks in which `getLastFinalizedMachineMerkleRoot` returns
    /// a different value after the application is foreclosed.
    error AccountsDriveMerkleRootAlreadyProved();

    /// @notice Raised when someone tries to validate an accounts Merkle root but the
    /// accounts drive Merkle root has not yet been proved through the
    /// `proveAccountsDriveMerkleRoot` function.
    error AccountsDriveMerkleRootNotProved();

    /// @notice Raised when the account root siblings array has an invalid length.
    /// @dev The array length should be log2 of the maximum number of accounts. See the
    /// `getLog2MaxNumOfAccounts` function.
    error InvalidAccountRootSiblingsArrayLength();

    /// @notice Raised when the computed machine Merkle root differs from the
    /// last-finalized machine Merkle root provided by the outputs Merkle root validator.
    /// @param machineMerkleRoot The computed machine Merkle root
    error InvalidMachineMerkleRoot(bytes32 machineMerkleRoot);

    /// @notice Raised when the computed accounts drive Merkle root differs
    /// from the one proved through the `proveAccountsDriveMerkleRoot` function.
    /// @param accountsDriveMerkleRoot The computed accounts drive Merkle root
    error InvalidAccountsDriveMerkleRoot(bytes32 accountsDriveMerkleRoot);

    /// @notice Raised when trying to withdraw funds of an account
    /// whose funds have already been withdrawn.
    /// @param accountIndex The account index
    error AccountFundsAlreadyWithdrawn(uint64 accountIndex);

    // Write functions

    /// @notice Prove the accounts drive Merkle root in the last-finalized machine state
    /// provided by the application's outputs Merkle root validator. This function can be
    /// called by anyone after the app is foreclosed so that accounts can be validated and
    /// their funds can be withdrawn.
    /// @param accountsDriveMerkleRoot The accounts drive Merkle root
    /// @param proof Siblings of the accounts drive Merkle root in the machine
    /// @dev May raise `NotForeclosed`, `AccountsDriveMerkleRootAlreadyProved`,
    /// `InvalidAccountsDriveMerkleRootProofSize` or `InvalidMachineMerkleRoot`.
    /// On success, stores the proved accounts drive Merkle root.
    function proveAccountsDriveMerkleRoot(
        bytes32 accountsDriveMerkleRoot,
        bytes32[] calldata proof
    ) external;

    /// @notice Withdraw the funds of an account from the foreclosed application.
    /// First, the account is validated against the proved accounts drive Merkle root.
    /// Then, a withdrawal output is built from the account, and executed.
    /// @param account The account
    /// @param proof The proof used to validate the account
    /// @dev May raise `NotForeclosed`, `AccountFundsAlreadyWithdrawn`,
    /// as well as any of the errors raised by `validateAccount`.
    /// On success, marks the account funds as withdrawn, and emits a `Withdrawal` event.
    function withdraw(bytes calldata account, AccountValidityProof calldata proof)
        external;

    // View Functions

    /// @notice Check whether the accounts drive Merkle root was proved and its value.
    /// @return wasAccountsDriveMerkleRootProved Whether the accounts drive Merkle root was proved
    /// @return accountsDriveMerkleRoot The accounts drive Merkle root (if proved)
    function getAccountsDriveMerkleRoot()
        external
        view
        returns (bool wasAccountsDriveMerkleRootProved, bytes32 accountsDriveMerkleRoot);

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

    /// @notice Get the factor that, when multiplied by the size of the accounts
    /// drive, yields the start memory address of the accounts drive.
    /// @dev If `a = getLog2LeavesPerAccount()` `b = getLog2MaxNumOfAccounts()`,
    /// and `c = getAccountsDriveStartIndex()`, then the accounts drive starts
    /// at memory address `c*2^{a+b+5}` and has `2^{a+b+5}` bytes in size.
    function getAccountsDriveStartIndex() external view returns (uint64);

    /// @notice Get the withdrawal output builder, which gets static-called
    /// whenever the funds of an account are to be withdrawn.
    function getWithdrawalOutputBuilder() external view returns (IWithdrawalOutputBuilder);

    /// @notice Validate the existence of an account at a given index
    /// on the accounts drive given a Merkle proof of the account root,
    /// according to the accounts drive Merkle root proved through the
    /// `proveAccountsDriveMerkleRoot` function.
    /// @param account The account
    /// @param proof The proof used to validate the account
    /// @dev May raise any of the errors raised by `validateAccountMerkleRoot`,
    /// as well as `DriveSmallerThanData` (if the provided account is too large).
    function validateAccount(bytes calldata account, AccountValidityProof calldata proof)
        external
        view;

    /// @notice Validate the existence of an account at a given index
    /// on the accounts drive given a Merkle proof of the account root,
    /// according to the accounts drive Merkle root proved through the
    /// `proveAccountsDriveMerkleRoot` function.
    /// @param accountMerkleRoot The account Merkle root
    /// @param proof The proof used to validate the account
    /// @dev May raise `InvalidAccountRootSiblingsArrayLength`, `InvalidNodeIndex`
    /// (if the account index is outside the boundaries of the accounts drive),
    /// `AccountsDriveMerkleRootNotProved` or `InvalidAccountsDriveMerkleRoot`.
    function validateAccountMerkleRoot(
        bytes32 accountMerkleRoot,
        AccountValidityProof calldata proof
    ) external view;
}
