// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {IERC721} from "@openzeppelin-contracts-5.2.0/token/ERC721/IERC721.sol";

import {InputEncoding} from "../common/InputEncoding.sol";
import {IErc721Portal} from "./IErc721Portal.sol";
import {Portal} from "./Portal.sol";

/// @title ERC-721 Portal
///
/// @notice This contract allows anyone to perform transfers of
/// ERC-721 tokens to an application contract while informing the off-chain machine.
contract Erc721Portal is IErc721Portal, Portal {
    function depositErc721Token(
        IERC721 token,
        address appContract,
        uint256 tokenId,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external override {
        token.safeTransferFrom(msg.sender, appContract, tokenId, baseLayerData);

        bytes memory payload = InputEncoding.encodeErc721Deposit(
            token, msg.sender, tokenId, baseLayerData, execLayerData
        );

        _addInput(appContract, payload);
    }
}
