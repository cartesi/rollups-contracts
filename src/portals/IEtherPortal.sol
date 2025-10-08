// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {App} from "../app/interfaces/App.sol";

/// @title Ether Portal interface
interface IEtherPortal {
    // Errors

    /// @notice Failed to transfer Ether to application
    error EtherTransferFailed();

    // Permissionless functions

    /// @notice Transfer Ether to an application contract
    /// and add an input to the application's inbox to signal such operation.
    ///
    /// @param appContract The application contract
    /// @param execLayerData Additional data to be interpreted by the execution layer
    ///
    /// @dev Any Ether sent through this function will be forwarded to the application contract.
    /// @dev If the transfer fails, an `EtherTransferFailed` error will be raised.
    /// @dev If the application contract is from an incompatible version of Cartesi Rollups Contracts,
    /// an `IncompatibleCartesiRollupsContractsVersion` error will be raised.
    function depositEther(App appContract, bytes calldata execLayerData)
        external
        payable;
}
