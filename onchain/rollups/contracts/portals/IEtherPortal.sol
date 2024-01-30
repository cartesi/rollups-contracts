// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IPortal} from "./IPortal.sol";

/// @title Ether Portal interface
interface IEtherPortal is IPortal {
    // Errors

    /// @notice Failed to transfer Ether to application
    error EtherTransferFailed();

    // Permissionless functions

    /// @notice Transfer Ether to an application and add an input to
    /// the application's input box to signal such operation.
    ///
    /// All the value sent through this function is forwarded to the application.
    ///
    /// @param app The address of the application
    /// @param execLayerData Additional data to be interpreted by the execution layer
    /// @dev All the value sent through this function is forwarded to the application.
    ///      If the transfer fails, an `EtherTransferFailed` error is raised.
    function depositEther(
        address app,
        bytes calldata execLayerData
    ) external payable;
}
