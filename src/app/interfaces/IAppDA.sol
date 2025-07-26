// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

interface IAppDA {
    /// @notice Get the source of data availability used by the application.
    function getDataAvailabilitySources() external pure returns (string[] memory);
}
