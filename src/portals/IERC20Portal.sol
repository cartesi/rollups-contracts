// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";

import {IApp} from "../app/interfaces/IApp.sol";
import {IPortal} from "./IPortal.sol";

/// @title ERC-20 Portal interface
interface IERC20Portal is IPortal {
    // Errors

    /// @notice Failed to transfer ERC-20 tokens to application
    error ERC20TransferFailed();

    // Permissionless functions

    /// @notice Transfer ERC-20 tokens to an application contract
    /// and add an input to the application's input box to signal such operation.
    ///
    /// The caller must allow the portal to withdraw at least `value` tokens
    /// from their account beforehand, by calling the `approve` function in the
    /// token contract.
    ///
    /// @param token The ERC-20 token contract
    /// @param appContract The application contract address
    /// @param value The amount of tokens to be transferred
    /// @param execLayerData Additional data to be interpreted by the execution layer
    function depositERC20Tokens(
        IERC20 token,
        IApp appContract,
        uint256 value,
        bytes calldata execLayerData
    ) external;
}
