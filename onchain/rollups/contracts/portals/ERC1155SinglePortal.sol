// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IERC1155SinglePortal} from "./IERC1155SinglePortal.sol";
import {Portal} from "./Portal.sol";
import {IInputBox} from "../inputs/IInputBox.sol";
import {InputEncoding} from "../common/InputEncoding.sol";

/// @title ERC-1155 Single Transfer Portal
///
/// @notice This contract allows anyone to perform single transfers of
/// ERC-1155 tokens to an application while informing the off-chain machine.
contract ERC1155SinglePortal is IERC1155SinglePortal, Portal {
    /// @notice Constructs the portal.
    /// @param inputBox The input box used by the portal
    constructor(IInputBox inputBox) Portal(inputBox) {}

    function depositSingleERC1155Token(
        IERC1155 token,
        address app,
        uint256 tokenId,
        uint256 value,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external override {
        token.safeTransferFrom(msg.sender, app, tokenId, value, baseLayerData);

        bytes memory payload = InputEncoding.encodeSingleERC1155Deposit(
            token,
            msg.sender,
            tokenId,
            value,
            baseLayerData,
            execLayerData
        );

        _inputBox.addInput(app, payload);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165, Portal) returns (bool) {
        return
            interfaceId == type(IERC1155SinglePortal).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
