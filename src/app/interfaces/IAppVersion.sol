// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

interface IAppVersion {
    //
    // View functions
    //

    /// @notice Get the major version of Cartesi Rollups Contracts used by the application.
    function cartesiRollupsContractsMajorVersion() external pure returns (uint256);
}
