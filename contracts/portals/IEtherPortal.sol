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

    /// @notice Transfer Ether to an application contract
    /// and add an input to the application's input box to signal such operation.
    ///
    /// @param appContract The application contract address
    /// @param execLayerData Additional data to be interpreted by the execution layer
    ///
    /// @dev Any Ether sent through this function will be forwarded to the application contract.
    ///      If the transfer fails, an `EtherTransferFailed` error will be raised.
    function depositEther(address appContract, bytes calldata execLayerData)
        external
        payable;
}
