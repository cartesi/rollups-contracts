// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {IERC721} from "@openzeppelin-contracts-5.2.0/token/ERC721/IERC721.sol";

/// @notice An ERC-721 token deposit
/// @param token The token contract
/// @param sender The token sender
/// @param tokenId The token identifier
struct Erc721Deposit {
    IERC721 token;
    address sender;
    uint256 tokenId;
}
