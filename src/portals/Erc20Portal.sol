// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";

import {InputEncoding} from "../common/InputEncoding.sol";
import {IErc20Portal} from "./IErc20Portal.sol";
import {Portal} from "./Portal.sol";

/// @title ERC-20 Portal
///
/// @notice This contract allows anyone to perform transfers of
/// ERC-20 tokens to an application contract while informing the off-chain machine.
contract Erc20Portal is IErc20Portal, Portal {
    function depositErc20Tokens(
        IERC20 token,
        address appContract,
        uint256 value,
        bytes calldata execLayerData
    ) external override {
        uint256 balanceBefore = token.balanceOf(appContract);

        bool success = token.transferFrom(msg.sender, appContract, value);

        if (!success) {
            revert Erc20TransferFailed();
        }

        uint256 balanceAfter = token.balanceOf(appContract);

        if (balanceAfter < balanceBefore) {
            revert Erc20TransferDecreasedApplicationBalance(balanceBefore, balanceAfter);
        }

        uint256 balanceDelta = balanceAfter - balanceBefore;

        if (value != balanceDelta) {
            revert Erc20TransferValueIsNotBalanceDelta(value, balanceDelta);
        }

        bytes memory payload =
            InputEncoding.encodeErc20Deposit(token, msg.sender, value, execLayerData);

        _addInput(appContract, payload);
    }
}
