// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Application Address Relay Test
pragma solidity ^0.8.8;

import {Test} from "forge-std/Test.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IApplicationAddressRelay} from "contracts/relays/IApplicationAddressRelay.sol";
import {ApplicationAddressRelay} from "contracts/relays/ApplicationAddressRelay.sol";
import {IInputBox} from "contracts/inputs/IInputBox.sol";
import {InputBox} from "contracts/inputs/InputBox.sol";
import {InputEncoding} from "contracts/common/InputEncoding.sol";
import {IInputRelay} from "contracts/inputs/IInputRelay.sol";

contract ApplicationAddressRelayTest is Test {
    IInputBox inputBox;
    IApplicationAddressRelay relay;

    event InputAdded(
        address indexed app,
        uint256 indexed inputIndex,
        address sender,
        bytes input
    );

    function setUp() public {
        inputBox = new InputBox();
        relay = new ApplicationAddressRelay(inputBox);
    }

    function testSupportsInterface(bytes4 _randomInterfaceId) public {
        assertTrue(
            relay.supportsInterface(type(IApplicationAddressRelay).interfaceId)
        );
        assertTrue(relay.supportsInterface(type(IInputRelay).interfaceId));
        assertTrue(relay.supportsInterface(type(IERC165).interfaceId));

        assertFalse(relay.supportsInterface(bytes4(0xffffffff)));

        vm.assume(
            _randomInterfaceId != type(IApplicationAddressRelay).interfaceId
        );
        vm.assume(_randomInterfaceId != type(IInputRelay).interfaceId);
        vm.assume(_randomInterfaceId != type(IERC165).interfaceId);
        assertFalse(relay.supportsInterface(_randomInterfaceId));
    }

    function testGetInputBox() public {
        assertEq(address(relay.getInputBox()), address(inputBox));
    }

    function testRelayApplicationAddress(address _app) public {
        // Check the application's input box before
        assertEq(inputBox.getNumberOfInputs(_app), 0);

        // Construct the application address relay input
        bytes memory input = abi.encodePacked(_app);

        // Expect InputAdded to be emitted with the right arguments
        vm.expectEmit(true, true, false, true, address(inputBox));
        emit InputAdded(_app, 0, address(relay), input);

        // Relay the application's address
        relay.relayApplicationAddress(_app);

        // Check the application's input box after
        assertEq(inputBox.getNumberOfInputs(_app), 1);
    }
}
