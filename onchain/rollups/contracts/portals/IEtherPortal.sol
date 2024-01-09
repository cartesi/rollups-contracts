// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IInputRelay} from "../inputs/IInputRelay.sol";

/// @title Ether Portal interface
interface IEtherPortal is IInputRelay {
    // Permissionless functions

    /// @notice Transfer Ether to an application and add an input to
    /// the application's input box to signal such operation.
    ///
    /// All the value sent through this function is forwarded to the application.
    ///
    /// @param app The address of the application
    /// @param execLayerData Additional data to be interpreted by the execution layer
    /// @dev All the value sent through this function is forwarded to the application.
    ///      If the transfer fails, `EtherTransferFailed` error is raised.
    function depositEther(
        address payable app,
        bytes calldata execLayerData
    ) external payable;
}
