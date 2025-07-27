// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IERC721} from "@openzeppelin-contracts-5.2.0/token/ERC721/IERC721.sol";

import {Application} from "../app/interfaces/Application.sol";
import {IERC721Portal} from "./IERC721Portal.sol";
import {InputEncoding} from "../common/InputEncoding.sol";
import {Portal} from "./Portal.sol";

/// @title ERC-721 Portal
///
/// @notice This contract allows anyone to perform transfers of
/// ERC-721 tokens to an application contract while informing the off-chain machine.
contract ERC721Portal is IERC721Portal, Portal {
    /// @inheritdoc IERC721Portal
    function depositERC721Token(
        IERC721 token,
        Application appContract,
        uint256 tokenId,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external override {
        token.safeTransferFrom(msg.sender, address(appContract), tokenId, baseLayerData);

        appContract.addInput(
            InputEncoding.encodeERC721Deposit(
                token, msg.sender, tokenId, baseLayerData, execLayerData
            )
        );
    }
}
