// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {DAppAddressRelay} from "contracts/relays/DAppAddressRelay.sol";
import {IDAppAddressRelay} from "contracts/relays/IDAppAddressRelay.sol";
import {IInputBox} from "contracts/inputs/IInputBox.sol";
import {IInputRelay} from "contracts/inputs/IInputRelay.sol";
import {InputBox} from "contracts/inputs/InputBox.sol";
import {InputEncoding} from "contracts/common/InputEncoding.sol";

import {ERC165Test} from "../util/ERC165Test.sol";

contract DAppAddressRelayTest is ERC165Test {
    address _alice;
    IInputBox _inputBox;
    IDAppAddressRelay _relay;

    function setUp() public {
        _alice = vm.addr(1);
        _inputBox = IInputBox(vm.addr(2));
        _relay = new DAppAddressRelay(_inputBox);
    }

    function getERC165Contract() public view override returns (IERC165) {
        return _relay;
    }

    function getSupportedInterfaces()
        public
        pure
        override
        returns (bytes4[] memory)
    {
        bytes4[] memory interfaceIds = new bytes4[](2);
        interfaceIds[0] = type(IDAppAddressRelay).interfaceId;
        interfaceIds[1] = type(IInputRelay).interfaceId;
        return interfaceIds;
    }

    function testGetInputBox() public {
        assertEq(address(_relay.getInputBox()), address(_inputBox));
    }

    function testRelayDAppAddress(address dapp) public {
        bytes memory input = _encodeInput(dapp);

        bytes memory addInput = _encodeAddInput(dapp, input);

        vm.mockCall(address(_inputBox), addInput, abi.encode(bytes32(0)));

        vm.expectCall(address(_inputBox), addInput, 1);

        vm.prank(_alice);
        _relay.relayDAppAddress(dapp);
    }

    function _encodeInput(address dapp) internal pure returns (bytes memory) {
        return InputEncoding.encodeDAppAddressRelay(dapp);
    }

    function _encodeAddInput(
        address dapp,
        bytes memory input
    ) internal pure returns (bytes memory) {
        return abi.encodeCall(IInputBox.addInput, (dapp, input));
    }
}
