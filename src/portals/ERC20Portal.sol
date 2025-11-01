// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";

import {InputEncoding} from "../common/InputEncoding.sol";
import {IInputBox} from "../inputs/IInputBox.sol";
import {IERC20Portal} from "./IERC20Portal.sol";
import {Portal} from "./Portal.sol";

/// @title ERC-20 Portal
///
/// @notice This contract allows anyone to perform transfers of
/// ERC-20 tokens to an application contract while informing the off-chain machine.
contract ERC20Portal is IERC20Portal, Portal {
    /// @notice Constructs the portal.
    /// @param inputBox The input box used by the portal
    constructor(IInputBox inputBox) Portal(inputBox) {}

    function depositERC20Tokens(
        IERC20 token,
        address appContract,
        uint256 value,
        bytes calldata execLayerData
    ) external override {
        bool success = token.transferFrom(msg.sender, appContract, value);

        if (!success) {
            revert ERC20TransferFailed();
        }

        bytes memory payload =
            InputEncoding.encodeERC20Deposit(token, msg.sender, value, execLayerData);

        getInputBox().addInput(appContract, payload);
    }
}
