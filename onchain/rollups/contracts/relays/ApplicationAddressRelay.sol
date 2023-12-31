// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IApplicationAddressRelay} from "./IApplicationAddressRelay.sol";
import {InputRelay} from "../inputs/InputRelay.sol";
import {IInputBox} from "../inputs/IInputBox.sol";
import {InputEncoding} from "../common/InputEncoding.sol";

/// @title Application Address Relay
///
/// @notice This contract allows anyone to inform the off-chain machine
/// of the address of the application contract in a trustless and permissionless way.
contract ApplicationAddressRelay is IApplicationAddressRelay, InputRelay {
    /// @notice Constructs the relay.
    /// @param _inputBox The input box used by the relay
    constructor(IInputBox _inputBox) InputRelay(_inputBox) {}

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165, InputRelay) returns (bool) {
        return
            interfaceId == type(IApplicationAddressRelay).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function relayApplicationAddress(address _app) external override {
        bytes memory input = InputEncoding.encodeApplicationAddressRelay(_app);
        inputBox.addInput(_app, input);
    }
}
