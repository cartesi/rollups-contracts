// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IEtherPortal} from "./IEtherPortal.sol";
import {Portal} from "./Portal.sol";
import {IInputBox} from "../inputs/IInputBox.sol";
import {InputEncoding} from "../common/InputEncoding.sol";

/// @title Ether Portal
///
/// @notice This contract allows anyone to perform transfers of
/// Ether to an application contract while informing the off-chain machine.
contract EtherPortal is IEtherPortal, Portal {
    /// @notice Constructs the portal.
    /// @param inputBox The input box used by the portal
    constructor(IInputBox inputBox) Portal(inputBox) {}

    function depositEther(address appContract, bytes calldata execLayerData)
        external
        payable
        override
    {
        (bool success,) = appContract.call{value: msg.value}("");

        if (!success) {
            revert EtherTransferFailed();
        }

        bytes memory payload = InputEncoding.encodeEtherDeposit(
            msg.sender, msg.value, execLayerData
        );

        _inputBox.addInput(appContract, payload);
    }
}
