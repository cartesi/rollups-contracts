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
    /// @param _inputBox The input box used by the portal
    constructor(IInputBox _inputBox) InputRelay(_inputBox) {}

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165, InputRelay) returns (bool) {
        return
            interfaceId == type(IERC1155BatchPortal).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function depositBatchERC1155Token(
        IERC1155 _token,
        address _app,
        uint256[] calldata _tokenIds,
        uint256[] calldata _values,
        bytes calldata _baseLayerData,
        bytes calldata _execLayerData
    ) external override {
        _token.safeBatchTransferFrom(
            msg.sender,
            _app,
            _tokenIds,
            _values,
            _baseLayerData
        );

        bytes memory input = InputEncoding.encodeBatchERC1155Deposit(
            _token,
            msg.sender,
            _tokenIds,
            _values,
            _baseLayerData,
            _execLayerData
        );

        inputBox.addInput(_app, input);
    }
}
