// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IERC20Portal} from "./IERC20Portal.sol";
import {InputRelay} from "../inputs/InputRelay.sol";
import {IInputBox} from "../inputs/IInputBox.sol";
import {InputEncoding} from "../common/InputEncoding.sol";

/// @title ERC-20 Portal
///
/// @notice This contract allows anyone to perform transfers of
/// ERC-20 tokens to an application while informing the off-chain machine.
contract ERC20Portal is IERC20Portal, InputRelay {
    /// @notice Constructs the portal.
    /// @param inputBox The input box used by the portal
    constructor(IInputBox inputBox) InputRelay(inputBox) {}

    function depositERC20Tokens(
        IERC20 token,
        address app,
        uint256 amount,
        bytes calldata execLayerData
    ) external override {
        bool success = token.transferFrom(msg.sender, app, amount);

        if (!success) {
            revert ERC20TransferFailed();
        }

        bytes memory input = InputEncoding.encodeERC20Deposit(
            token,
            msg.sender,
            amount,
            execLayerData
        );

        _inputBox.addInput(app, input);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165, InputRelay) returns (bool) {
        return
            interfaceId == type(IERC20Portal).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
