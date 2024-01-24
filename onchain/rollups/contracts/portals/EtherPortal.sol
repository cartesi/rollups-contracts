// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IEtherPortal} from "./IEtherPortal.sol";
import {InputRelay} from "../inputs/InputRelay.sol";
import {IInputBox} from "../inputs/IInputBox.sol";
import {InputEncoding} from "../common/InputEncoding.sol";

/// @title Ether Portal
///
/// @notice This contract allows anyone to perform transfers of
/// Ether to an application while informing the off-chain machine.
contract EtherPortal is IEtherPortal, InputRelay {
    /// @notice Constructs the portal.
    /// @param inputBox The input box used by the portal
    constructor(IInputBox inputBox) InputRelay(inputBox) {}

    function depositEther(
        address app,
        bytes calldata execLayerData
    ) external payable override {
        (bool success, ) = app.call{value: msg.value}("");

        if (!success) {
            revert EtherTransferFailed();
        }

        bytes memory payload = InputEncoding.encodeEtherDeposit(
            msg.sender,
            msg.value,
            execLayerData
        );

        _inputBox.addInput(app, payload);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165, InputRelay) returns (bool) {
        return
            interfaceId == type(IEtherPortal).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
