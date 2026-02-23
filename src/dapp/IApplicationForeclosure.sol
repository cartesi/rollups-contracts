// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

interface IApplicationForeclosure {
    // Events

    /// @notice MUST trigger when the application is foreclosed.
    event Foreclosure();

    // Errors

    /// @notice Raised when a function that can only be called by
    /// the application guardian is called by some other account.
    error NotGuardian();

    // Permissioned functions

    /// @notice Forecloses the application, allowing users to withdraw their funds
    /// by providing Merkle proofs of their in-app accounts.
    /// @dev Can only be called by the application guardian.
    function foreclose() external;

    // Permissionless functions

    /// @notice Get the address of the guardian,
    /// which has the power to foreclose the application.
    function getGuardian() external view returns (address);

    /// @notice Check whether the application has been foreclosed.
    /// An application that has been foreclosed will remain so.
    function isForeclosed() external view returns (bool);
}
