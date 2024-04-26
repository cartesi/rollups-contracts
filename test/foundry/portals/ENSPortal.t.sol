// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {ENS} from "@ensdomains/ens-contracts/contracts/registry/ENS.sol";
import {AddrResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/AddrResolver.sol";

import {ENSPortal} from "contracts/portals/ENSPortal.sol";
import {IENSPortal} from "contracts/portals/IENSPortal.sol";
import {IInputBox} from "contracts/inputs/IInputBox.sol";
import {IPortal} from "contracts/portals/IPortal.sol";
import {InputEncoding} from "contracts/common/InputEncoding.sol";

import {ERC165Test} from "../util/ERC165Test.sol";

contract ENSPortalTest is ERC165Test {
    IInputBox _inputBox;
    IENSPortal _portal;
    ENS _ens;
    AddrResolver _resolver;

    address _inputSender;
    address _appContract;
    bytes4[] _interfaceIds;

    bytes32 constant _node = keccak256("user.eth");

    function setUp() public {
        _inputSender = _newAddr();
        _appContract = _newAddr();
        _inputBox = IInputBox(_newAddr());
        _ens = ENS(_newAddr());
        _portal = new ENSPortal(_inputBox, _ens);
        _resolver = AddrResolver(_newAddr());

        vm.mockCall(
            address(_ens),
            abi.encodeCall(ENS.resolver, (_node)),
            abi.encode(_resolver)
        );
        vm.mockCall(
            address(_resolver),
            abi.encodeWithSignature("addr(bytes32)", (_node)),
            abi.encode(_inputSender)
        );

        _interfaceIds.push(type(IENSPortal).interfaceId);
        _interfaceIds.push(type(IPortal).interfaceId);
    }

    function getERC165Contract() public view override returns (IERC165) {
        return _portal;
    }

    function getSupportedInterfaces()
        public
        view
        override
        returns (bytes4[] memory)
    {
        return _interfaceIds;
    }

    function testGetInputBox() public view {
        assertEq(address(_portal.getInputBox()), address(_inputBox));
    }

    function testGetENS() public view {
        assertEq(address(_portal.getENS()), address(_ens));
    }

    function testAddressResolutionMismatch(
        address incorrectSender,
        bytes calldata name,
        bytes calldata execLayerData
    ) public {
        vm.assume(incorrectSender != _inputSender);

        vm.expectRevert(
            abi.encodeWithSelector(
                IENSPortal.AddressResolutionMismatch.selector,
                _inputSender,
                incorrectSender
            )
        );
        vm.prank(incorrectSender);
        _portal.sendInputWithENS(_appContract, _node, name, execLayerData);
    }

    function testSendInput(
        bytes calldata name,
        bytes calldata execLayerData
    ) public {
        bytes memory payload = _encodePayload(_node, name, execLayerData);
        bytes memory addInput = _encodeAddInput(payload);

        vm.mockCall(address(_inputBox), addInput, abi.encode(bytes32(0)));
        vm.expectCall(address(_inputBox), addInput, 1);
        vm.prank(_inputSender);
        _portal.sendInputWithENS(_appContract, _node, name, execLayerData);
    }

    function _encodePayload(
        bytes32 node,
        bytes calldata name,
        bytes calldata execLayerData
    ) internal pure returns (bytes memory) {
        return InputEncoding.encodeENSInput(node, name, execLayerData);
    }

    function _encodeAddInput(
        bytes memory payload
    ) internal view returns (bytes memory) {
        return abi.encodeCall(IInputBox.addInput, (_appContract, payload));
    }
}
