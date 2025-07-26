// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

interface IAppMetadata {
    //
    // View functions
    //

    /// @notice Get the major version of Cartesi Rollups Contracts used by the application.
    function getCartesiRollupsContractsMajorVersion() external pure returns (uint256);

    /// @notice Get the ID of the data availability interface used by the application.
    /// @dev This can be the XOR of more than one interface ID.
    function getDataAvailabilityInterfaceId() external pure returns (bytes4);
}
