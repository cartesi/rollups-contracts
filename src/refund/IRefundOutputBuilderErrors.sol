// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

interface IRefundOutputBuilderErrors {
    /// @notice This error is raised whenever a user provides an input whose sender is
    /// unknown to the refund output builder contract. Usually, this happens when the user
    /// provides a non-deposit input or an input sent by a non-canonical portal contract.
    /// @param inputSender The input sender
    error UnknownInputSender(address inputSender);
}
