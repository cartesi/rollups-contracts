// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";

/// @notice An ERC-20 token deposit
/// @param token The token contract
/// @param sender The token sender
/// @param value The token amount
struct Erc20Deposit {
    IERC20 token;
    address sender;
    uint256 value;
}
