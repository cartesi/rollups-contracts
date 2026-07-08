// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

interface AddressErrors {
    /// @notice Could not execute an output, because the application contract doesn't have enough Ether.
    /// @param value The amount of Wei necessary for the execution of the output
    /// @param balance The current application contract balance
    error InsufficientFunds(uint256 value, uint256 balance);

    /// @notice Could not execute an output, because the target account doesn't have any code.
    /// @param target The target account address
    error TargetHasNoCode(address target);
}
