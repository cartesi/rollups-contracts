// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";

import {IVersionGetter} from "../common/IVersionGetter.sol";

interface ISafeERC20Transfer is IVersionGetter {
    /// @notice Safely transfer ERC-20 tokens.
    /// @param token The ERC-20 token contract
    /// @param to The token receipient address
    /// @param value The amount of tokens
    function safeTransfer(IERC20 token, address to, uint256 value) external;
}
