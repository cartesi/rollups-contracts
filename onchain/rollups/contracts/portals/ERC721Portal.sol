// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IERC721Portal} from "./IERC721Portal.sol";
import {InputRelay} from "../inputs/InputRelay.sol";
import {IInputBox} from "../inputs/IInputBox.sol";
import {InputEncoding} from "../common/InputEncoding.sol";

/// @title ERC-721 Portal
///
/// @notice This contract allows anyone to perform transfers of
/// ERC-721 tokens to an application while informing the off-chain machine.
contract ERC721Portal is IERC721Portal, InputRelay {
    /// @notice Constructs the portal.
    /// @param _inputBox The input box used by the portal
    constructor(IInputBox _inputBox) InputRelay(_inputBox) {}

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165, InputRelay) returns (bool) {
        return
            interfaceId == type(IERC721Portal).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function depositERC721Token(
        IERC721 _token,
        address _app,
        uint256 _tokenId,
        bytes calldata _baseLayerData,
        bytes calldata _execLayerData
    ) external override {
        _token.safeTransferFrom(msg.sender, _app, _tokenId, _baseLayerData);

        bytes memory input = InputEncoding.encodeERC721Deposit(
            _token,
            msg.sender,
            _tokenId,
            _baseLayerData,
            _execLayerData
        );

        inputBox.addInput(_app, input);
    }
}
