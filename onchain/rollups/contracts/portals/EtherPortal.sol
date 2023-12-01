// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IEtherPortal} from "./IEtherPortal.sol";
import {InputRelay} from "../inputs/InputRelay.sol";
import {IInputBox} from "../inputs/IInputBox.sol";
import {InputEncoding} from "../common/InputEncoding.sol";

/// @title Ether Portal
///
/// @notice This contract allows anyone to perform transfers of
/// Ether to a DApp while informing the off-chain machine.
contract EtherPortal is IEtherPortal, InputRelay {
    using Address for address payable;

    /// @notice Constructs the portal.
    /// @param _inputBox The input box used by the portal
    constructor(IInputBox _inputBox) InputRelay(_inputBox) {}

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165, InputRelay) returns (bool) {
        return
            interfaceId == type(IEtherPortal).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function depositEther(
        address payable _dapp,
        bytes calldata _execLayerData
    ) external payable override {
        _dapp.sendValue(msg.value);

        bytes memory input = InputEncoding.encodeEtherDeposit(
            msg.sender,
            msg.value,
            _execLayerData
        );

        inputBox.addInput(_dapp, input);
    }
}
