// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

/// @title Portal interface
interface IPortal {
    /// @notice Tried to interact with an application contract
    /// but it uses an incompatible version of Cartesi Rollups.
    error IncompatibleApplicationVersion();

    /// @notice Tried to interact with an application contract
    /// but the call either failed or returned malformed data.
    error FailedApplicationVersionLookup();
}
