// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IERC1155} from "@openzeppelin-contracts-5.2.0/token/ERC1155/IERC1155.sol";

import {InputEncoding} from "../common/InputEncoding.sol";
import {IInputBox} from "../inputs/IInputBox.sol";
import {IERC1155BatchPortal} from "./IERC1155BatchPortal.sol";
import {Portal} from "./Portal.sol";

/// @title ERC-1155 Batch Transfer Portal
///
/// @notice This contract allows anyone to perform batch transfers of
/// ERC-1155 tokens to an application contract while informing the off-chain machine.
contract ERC1155BatchPortal is IERC1155BatchPortal, Portal {
    /// @notice Constructs the portal.
    /// @param inputBox The input box used by the portal
    constructor(IInputBox inputBox) Portal(inputBox) {}

    function depositBatchERC1155Token(
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

        bytes memory payload = InputEncoding.encodeBatchERC1155Deposit(
            token, msg.sender, tokenIds, values, baseLayerData, execLayerData
        );

        _INPUT_BOX.addInput(appContract, payload);
    }
}
