// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {IERC721Portal} from "./IERC721Portal.sol";
import {Portal} from "./Portal.sol";
import {IInputBox} from "../inputs/IInputBox.sol";
import {InputEncoding} from "../common/InputEncoding.sol";

/// @title ERC-721 Portal
///
/// @notice This contract allows anyone to perform transfers of
/// ERC-721 tokens to an application contract while informing the off-chain machine.
contract ERC721Portal is IERC721Portal, Portal {
    /// @notice Constructs the portal.
    /// @param inputBox The input box used by the portal
    constructor(IInputBox inputBox) Portal(inputBox) {}

    function depositERC721Token(
        IERC721 token,
        address appContract,
        uint256 tokenId,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external override {
        token.safeTransferFrom(msg.sender, appContract, tokenId, baseLayerData);

        bytes memory payload = InputEncoding.encodeERC721Deposit(
            token, msg.sender, tokenId, baseLayerData, execLayerData
        );

        _inputBox.addInput(appContract, payload);
    }
}
