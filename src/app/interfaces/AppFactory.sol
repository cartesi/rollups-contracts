// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

/// @notice Defines functions that are common to all app factories.
interface AppFactory {
    /// @notice Get the number of apps deployed by the factory.
    function getDeployedAppCount() external view returns (uint256 deployedAppCount);
}
