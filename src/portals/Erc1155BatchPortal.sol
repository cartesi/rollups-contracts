// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {IERC1155} from "@openzeppelin-contracts-5.2.0/token/ERC1155/IERC1155.sol";

import {InputEncoding} from "../common/InputEncoding.sol";
import {IErc1155BatchPortal} from "./IErc1155BatchPortal.sol";
import {Portal} from "./Portal.sol";

/// @title ERC-1155 Batch Transfer Portal
///
/// @notice This contract allows anyone to perform batch transfers of
/// ERC-1155 tokens to an application contract while informing the off-chain machine.
contract Erc1155BatchPortal is IErc1155BatchPortal, Portal {
    function depositBatchErc1155Token(
        IERC1155 token,
        address appContract,
        uint256[] calldata tokenIds,
        uint256[] calldata values,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external override {
        token.safeBatchTransferFrom(
            msg.sender, appContract, tokenIds, values, baseLayerData
        );

        bytes memory payload = InputEncoding.encodeBatchErc1155Deposit(
            token, msg.sender, tokenIds, values, baseLayerData, execLayerData
        );

        _addInput(appContract, payload);
    }
}
