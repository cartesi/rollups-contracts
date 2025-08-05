// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";

import {App} from "../app/interfaces/App.sol";
import {IERC20Portal} from "./IERC20Portal.sol";
import {InputEncoding} from "../common/InputEncoding.sol";
import {Portal} from "./Portal.sol";

/// @title ERC-20 Portal
///
/// @notice This contract allows anyone to perform transfers of
/// ERC-20 tokens to an application contract while informing the off-chain machine.
contract ERC20Portal is IERC20Portal, Portal {
    /// @inheritdoc IERC20Portal
    function depositERC20Tokens(
        IERC20 token,
        App appContract,
        uint256 value,
        bytes calldata execLayerData
    ) external override {
        bool success = token.transferFrom(msg.sender, address(appContract), value);

        require(success, ERC20TransferFailed());

        appContract.addInput(
            InputEncoding.encodeERC20Deposit(token, msg.sender, value, execLayerData)
        );
    }
}
