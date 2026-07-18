// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {IERC1155} from "@openzeppelin-contracts-5.2.0/token/ERC1155/IERC1155.sol";

import {InputEncoding} from "../common/InputEncoding.sol";
import {IErc1155SinglePortal} from "./IErc1155SinglePortal.sol";
import {Portal} from "./Portal.sol";

/// @title ERC-1155 Single Transfer Portal
///
/// @notice This contract allows anyone to perform single transfers of
/// ERC-1155 tokens to an application contract while informing the off-chain machine.
contract Erc1155SinglePortal is IErc1155SinglePortal, Portal {
    function depositSingleErc1155Token(
        IERC1155 token,
        address appContract,
        uint256 tokenId,
        uint256 value,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external override {
        token.safeTransferFrom(msg.sender, appContract, tokenId, value, baseLayerData);

        bytes memory payload = InputEncoding.encodeSingleErc1155Deposit(
            token, msg.sender, tokenId, value, baseLayerData, execLayerData
        );

        _addInput(appContract, payload);
    }
}
