// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

/// @notice Proof of inclusion of an account in the accounts drive.
/// @param accountIndex Index of account in the accounts drive
/// @param accountRootSiblings Siblings of the account root in the accounts drive
/// @dev From the index and siblings, one can calculate the accounts drive root.
/// @dev The siblings array should have size equal to the log2 of the maximum number of accounts.
struct AccountValidityProof {
    uint64 accountIndex;
    bytes32[] accountRootSiblings;
}
