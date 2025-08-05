// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IERC1155} from "@openzeppelin-contracts-5.2.0/token/ERC1155/IERC1155.sol";

import {App} from "../app/interfaces/App.sol";
import {IERC1155BatchPortal} from "./IERC1155BatchPortal.sol";
import {InputEncoding} from "../common/InputEncoding.sol";
import {Portal} from "./Portal.sol";

/// @title ERC-1155 Batch Transfer Portal
///
/// @notice This contract allows anyone to perform batch transfers of
/// ERC-1155 tokens to an application contract while informing the off-chain machine.
contract ERC1155BatchPortal is IERC1155BatchPortal, Portal {
    /// @inheritdoc IERC1155BatchPortal
    function depositBatchERC1155Token(
        IERC1155 token,
        App appContract,
        uint256[] calldata tokenIds,
        uint256[] calldata values,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external override {
        token.safeBatchTransferFrom(
            msg.sender, address(appContract), tokenIds, values, baseLayerData
        );

        appContract.addInput(
            InputEncoding.encodeBatchERC1155Deposit(
                token, msg.sender, tokenIds, values, baseLayerData, execLayerData
            )
        );
    }
}
