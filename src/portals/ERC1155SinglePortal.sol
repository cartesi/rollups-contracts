// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IERC1155} from "@openzeppelin-contracts-5.2.0/token/ERC1155/IERC1155.sol";

import {IERC1155SinglePortal} from "./IERC1155SinglePortal.sol";
import {IApp} from "../app/interfaces/IApp.sol";
import {InputEncoding} from "../common/InputEncoding.sol";
import {Portal} from "./Portal.sol";

/// @title ERC-1155 Single Transfer Portal
///
/// @notice This contract allows anyone to perform single transfers of
/// ERC-1155 tokens to an application contract while informing the off-chain machine.
contract ERC1155SinglePortal is IERC1155SinglePortal, Portal {
    /// @inheritdoc IERC1155SinglePortal
    function depositSingleERC1155Token(
        IERC1155 token,
        IApp appContract,
        uint256 tokenId,
        uint256 value,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external override {
        token.safeTransferFrom(
            msg.sender, address(appContract), tokenId, value, baseLayerData
        );

        appContract.addInput(
            InputEncoding.encodeSingleERC1155Deposit(
                token, msg.sender, tokenId, value, baseLayerData, execLayerData
            )
        );
    }
}
