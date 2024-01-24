// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IERC1155BatchPortal} from "./IERC1155BatchPortal.sol";
import {InputRelay} from "../inputs/InputRelay.sol";
import {IInputBox} from "../inputs/IInputBox.sol";
import {InputEncoding} from "../common/InputEncoding.sol";

/// @title ERC-1155 Batch Transfer Portal
///
/// @notice This contract allows anyone to perform batch transfers of
/// ERC-1155 tokens to an application while informing the off-chain machine.
contract ERC1155BatchPortal is IERC1155BatchPortal, InputRelay {
    /// @notice Constructs the portal.
    /// @param inputBox The input box used by the portal
    constructor(IInputBox inputBox) InputRelay(inputBox) {}

    function depositBatchERC1155Token(
        IERC1155 token,
        address app,
        uint256[] calldata tokenIds,
        uint256[] calldata values,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external override {
        token.safeBatchTransferFrom(
            msg.sender,
            app,
            tokenIds,
            values,
            baseLayerData
        );

        bytes memory payload = InputEncoding.encodeBatchERC1155Deposit(
            token,
            msg.sender,
            tokenIds,
            values,
            baseLayerData,
            execLayerData
        );

        _inputBox.addInput(app, payload);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165, InputRelay) returns (bool) {
        return
            interfaceId == type(IERC1155BatchPortal).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
