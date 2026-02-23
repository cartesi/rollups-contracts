// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

interface IApplicationChecker {
    /// @notice The application contract address contains no code.
    /// @param appContract The application contract address
    error ApplicationNotDeployed(address appContract);

    /// @notice The call to the application contract reverted with an error.
    /// @param appContract The application contract address
    /// @param error The error raised by the application contract
    error ApplicationReverted(address appContract, bytes error);

    /// @notice The call to the application contract returned ill-formed data.
    /// @param appContract The application contract address
    /// @param data The data returned by the application contract
    error IllformedApplicationReturnData(address appContract, bytes data);

    /// @notice Application was foreclosed.
    /// @param appContract The application contract address
    error ApplicationForeclosed(address appContract);
}
