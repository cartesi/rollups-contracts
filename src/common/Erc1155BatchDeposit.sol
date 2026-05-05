// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {IERC1155} from "@openzeppelin-contracts-5.2.0/token/ERC1155/IERC1155.sol";

/// @notice An ERC-1155 single token deposit
/// @param token The token contract
/// @param sender The token sender
/// @param tokenIds The token identifiers
/// @param value The token amounts per token type
struct Erc1155BatchDeposit {
    IERC1155 token;
    address sender;
    uint256[] tokenIds;
    uint256[] values;
}
