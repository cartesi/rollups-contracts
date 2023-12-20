// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IInputRelay} from "../inputs/IInputRelay.sol";

/// @title Application Address Relay interface
interface IApplicationAddressRelay is IInputRelay {
    // Permissionless functions

    /// @notice Add an input to an application's input box with its address.
    /// @param _app The address of the application
    function relayApplicationAddress(address _app) external;
}
