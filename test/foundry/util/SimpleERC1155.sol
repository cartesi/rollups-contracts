// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title A Simple ERC-20 Contract
pragma solidity ^0.8.22;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract SimpleSingleERC1155 is ERC1155 {
    constructor(
        address tokenOwner,
        uint256 tokenId,
        uint256 supply
    ) ERC1155("SimpleSingleERC1155") {
        _mint(tokenOwner, tokenId, supply, "");
    }
}

contract SimpleBatchERC1155 is ERC1155 {
    constructor(
        address tokenOwner,
        uint256[] memory tokenIds,
        uint256[] memory supplies
    ) ERC1155("SimpleBatchERC1155") {
        _mintBatch(tokenOwner, tokenIds, supplies, "");
    }
}
