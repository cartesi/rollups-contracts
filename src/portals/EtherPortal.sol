// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {Application} from "../app/interfaces/Application.sol";
import {IEtherPortal} from "./IEtherPortal.sol";
import {InputEncoding} from "../common/InputEncoding.sol";
import {Portal} from "./Portal.sol";

/// @title Ether Portal
///
/// @notice This contract allows anyone to perform transfers of
/// Ether to an application contract while informing the off-chain machine.
contract EtherPortal is IEtherPortal, Portal {
    /// @inheritdoc IEtherPortal
    function depositEther(Application appContract, bytes calldata execLayerData)
        external
        payable
        override
    {
        (bool success,) = address(appContract).call{value: msg.value}("");

        require(success, EtherTransferFailed());

        appContract.addInput(
            InputEncoding.encodeEtherDeposit(msg.sender, msg.value, execLayerData)
        );
    }
}
