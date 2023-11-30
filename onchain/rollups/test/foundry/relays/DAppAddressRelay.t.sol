// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title DApp Address Relay Test
pragma solidity ^0.8.8;

import {Test} from "forge-std/Test.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IDAppAddressRelay} from "contracts/relays/IDAppAddressRelay.sol";
import {DAppAddressRelay} from "contracts/relays/DAppAddressRelay.sol";
import {IInputBox} from "contracts/inputs/IInputBox.sol";
import {InputBox} from "contracts/inputs/InputBox.sol";
import {InputEncoding} from "contracts/common/InputEncoding.sol";
import {IInputRelay} from "contracts/inputs/IInputRelay.sol";

contract DAppAddressRelayTest is Test {
    IInputBox inputBox;
    IDAppAddressRelay relay;

    event InputAdded(
        address indexed dapp,
        uint256 indexed inputIndex,
        address sender,
        bytes input
    );

    function setUp() public {
        inputBox = new InputBox();
        relay = new DAppAddressRelay(inputBox);
    }

    function testSupportsInterface(bytes4 _randomInterfaceId) public {
        assertTrue(
            relay.supportsInterface(type(IDAppAddressRelay).interfaceId)
        );
        assertTrue(relay.supportsInterface(type(IInputRelay).interfaceId));
        assertTrue(relay.supportsInterface(type(IERC165).interfaceId));

        assertFalse(relay.supportsInterface(bytes4(0xffffffff)));

        vm.assume(_randomInterfaceId != type(IDAppAddressRelay).interfaceId);
        vm.assume(_randomInterfaceId != type(IInputRelay).interfaceId);
        vm.assume(_randomInterfaceId != type(IERC165).interfaceId);
        assertFalse(relay.supportsInterface(_randomInterfaceId));
    }

    function testGetInputBox() public {
        assertEq(address(relay.getInputBox()), address(inputBox));
    }

    function testRelayDAppAddress(address _dapp) public {
        // Check the DApp's input box before
        assertEq(inputBox.getNumberOfInputs(_dapp), 0);

        // Construct the DApp address relay input
        bytes memory input = abi.encodePacked(_dapp);

        // Expect InputAdded to be emitted with the right arguments
        vm.expectEmit(true, true, false, true, address(inputBox));
        emit InputAdded(_dapp, 0, address(relay), input);

        // Relay the DApp's address
        relay.relayDAppAddress(_dapp);

        // Check the DApp's input box after
        assertEq(inputBox.getNumberOfInputs(_dapp), 1);
    }
}
