// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {IPortal} from "./IPortal.sol";
import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";

/// @title ERC-20 Portal interface
interface IERC20Portal is IPortal {
    // Errors

    /// @notice Failed to transfer ERC-20 tokens to application
    error ERC20TransferFailed();

    /// @notice ERC-20 transfer decreased application balance
    /// @param balanceBefore The application balance before the transfer
    /// @param balanceAfter The application balance after the transfer
    error ERC20TransferDecreasedApplicationBalance(
        uint256 balanceBefore, uint256 balanceAfter
    );

    /// @notice ERC-20 transfer value is different from application balance delta
    /// @param value The transfer value
    /// @param balanceDelta The application balance delta (after - before)
    error ERC20TransferValueIsNotBalanceDelta(uint256 value, uint256 balanceDelta);

    // Permissionless functions

    /// @notice Transfer ERC-20 tokens to an application contract
    /// and add an input to the application's input box to signal such operation.
    ///
    /// The caller must allow the portal to withdraw at least `value` tokens
    /// from their account beforehand, by calling the `approve` function in the
    /// token contract.
    ///
    /// Only ERC-20 compliant tokens are supported. The portal rejects deposits
    /// of fee-on-transfer ERC-20 tokens: It computes the difference between
    /// balances before and after the transfer. If the difference is not equal
    /// to the transfer amount, it reverts with an appropriate custom error.
    /// The portal also ensures the return value of `transferFrom` is `true`,
    /// as specified in the ERC-20 standard. Empty or ill-formed return values
    /// are not accepted and a low-level generic error is raised in those cases.
    ///
    /// @param token The ERC-20 token contract
    /// @param appContract The application contract address
    /// @param value The amount of tokens to be transferred
    /// @param execLayerData Additional data to be interpreted by the execution layer
    ///
    /// @dev May raise ERC20TransferFailed, ERC20TransferDecreasedApplicationBalance,
    /// or ERC20TransferValueIsNotBalanceDelta.
    function depositERC20Tokens(
        IERC20 token,
        address appContract,
        uint256 value,
        bytes calldata execLayerData
    ) external;
}
