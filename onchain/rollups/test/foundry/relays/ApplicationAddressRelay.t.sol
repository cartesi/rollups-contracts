// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Application Address Relay Test
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IApplicationAddressRelay} from "contracts/relays/IApplicationAddressRelay.sol";
import {ApplicationAddressRelay} from "contracts/relays/ApplicationAddressRelay.sol";
import {IInputBox} from "contracts/inputs/IInputBox.sol";
import {InputBox} from "contracts/inputs/InputBox.sol";
import {IInputRelay} from "contracts/inputs/IInputRelay.sol";

import {EvmAdvanceEncoder} from "../util/EvmAdvanceEncoder.sol";

contract ApplicationAddressRelayTest is Test {
    IInputBox _inputBox;
    IApplicationAddressRelay _relay;

    function setUp() public {
        _inputBox = new InputBox();
        _relay = new ApplicationAddressRelay(_inputBox);
    }

    function testSupportsInterface(bytes4 randomInterfaceId) public {
        assertTrue(
            _relay.supportsInterface(type(IApplicationAddressRelay).interfaceId)
        );
        assertTrue(_relay.supportsInterface(type(IInputRelay).interfaceId));
        assertTrue(_relay.supportsInterface(type(IERC165).interfaceId));

        assertFalse(_relay.supportsInterface(bytes4(0xffffffff)));

        vm.assume(
            randomInterfaceId != type(IApplicationAddressRelay).interfaceId
        );
        vm.assume(randomInterfaceId != type(IInputRelay).interfaceId);
        vm.assume(randomInterfaceId != type(IERC165).interfaceId);
        assertFalse(_relay.supportsInterface(randomInterfaceId));
    }

    function testGetInputBox() public {
        assertEq(address(_relay.getInputBox()), address(_inputBox));
    }

    function testRelayApplicationAddress(address app) public {
        // Check the application's input box before
        assertEq(_inputBox.getNumberOfInputs(app), 0);

        // Construct the application address relay input
        bytes memory payload = abi.encodePacked(app);
        bytes memory input = EvmAdvanceEncoder.encode(
            address(_relay),
            0,
            payload
        );

        // Expect InputAdded to be emitted with the right arguments
        vm.expectEmit(true, true, false, true, address(_inputBox));
        emit IInputBox.InputAdded(app, 0, input);

        // Relay the application's address
        _relay.relayApplicationAddress(app);

        // Check the application's input box after
        assertEq(_inputBox.getNumberOfInputs(app), 1);
    }
}
