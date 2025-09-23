// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";

interface ISafeERC20Transfer {
    /// @notice Safely transfer ERC-20 tokens to an address.
    /// @param token The ERC-20 token contract
    /// @param to The token recipient address
    /// @param value The amount of tokens to transfer
    function safeTransfer(IERC20 token, address to, uint256 value) external;
}
