// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Test} from "forge-std-1.9.6/src/Test.sol";
import {Vm} from "forge-std-1.9.6/src/Vm.sol";

import {IInputBox} from "src/inputs/IInputBox.sol";
import {InputBox} from "src/inputs/InputBox.sol";
import {EtherPortal} from "src/portals/EtherPortal.sol";
import {IEtherPortal} from "src/portals/IEtherPortal.sol";

import {InputBoxTestUtils} from "../util/InputBoxTestUtils.sol";
import {LibBytes} from "../util/LibBytes.sol";

contract EtherPortalTest is Test, InputBoxTestUtils {
    using LibBytes for bytes;

    IInputBox _inputBox;
    IEtherPortal _portal;

    function setUp() external {
        _inputBox = new InputBox();
        _portal = new EtherPortal(_inputBox);
    }

    function testGetInputBox() external view {
        assertEq(address(_portal.getInputBox()), address(_inputBox));
    }

    function testDepositRevertApplicationNotDeployed(
        uint256 value,
        bytes calldata execLayerData
    ) external {
        address sender = _randomAccountWithNoCode();
        address appContract = _randomAccountWithNoCode();

        _randomSetup(sender, appContract, value);

        vm.prank(sender);
        vm.expectRevert(_encodeApplicationNotDeployed(appContract));
        _portal.depositEther{value: value}(appContract, execLayerData);
    }

    function testDepositRevertApplicationReverted(
        uint256 value,
        bytes calldata execLayerData,
        bytes calldata error
    ) external {
        address sender = _randomAccountWithNoCode();
        address appContract = _newAppMockReverts(error);

        _randomSetup(sender, appContract, value);

        vm.prank(sender);
        vm.expectRevert(_encodeApplicationReverted(appContract, error));
        _portal.depositEther{value: value}(appContract, execLayerData);
    }

    function testDepositRevertIllformedApplicationReturnDataSize(
        uint256 value,
        bytes calldata execLayerData,
        bytes calldata returnData
    ) external {
        vm.assume(returnData.length != 32);

        address sender = _randomAccountWithNoCode();
        address appContract = _newAppMockReturns(returnData);

        _randomSetup(sender, appContract, value);

        vm.prank(sender);
        vm.expectRevert(_encodeIllformedApplicationReturnData(appContract, returnData));
        _portal.depositEther{value: value}(appContract, execLayerData);
    }

    function testDepositRevertIllformedApplicationReturnDataInvalidBool(
        uint256 value,
        bytes calldata execLayerData
    ) external {
        uint256 returnValue = vm.randomUint(2, type(uint256).max);
        bytes memory returnData = abi.encode(returnValue);

        address sender = _randomAccountWithNoCode();
        address appContract = _newAppMockReturns(returnData);

        _randomSetup(sender, appContract, value);

        vm.prank(sender);
        vm.expectRevert(_encodeIllformedApplicationReturnData(appContract, returnData));
        _portal.depositEther{value: value}(appContract, execLayerData);
    }

    function testDepositRevertApplicationForeclosed(
        uint256 value,
        bytes calldata execLayerData
    ) external {
        address sender = _randomAccountWithNoCode();
        address appContract = _newForeclosedAppMock();

        _randomSetup(sender, appContract, value);

        vm.prank(sender);
        vm.expectRevert(_encodeApplicationForeclosed(appContract));
        _portal.depositEther{value: value}(appContract, execLayerData);
    }

    function testDeposit(
        uint256 value,
        bytes calldata execLayerData,
        bytes[] calldata payloads
    ) external {
        address sender = _randomAccountWithNoCode();
        address appContract = _newActiveAppMock();

        _randomSetup(sender, appContract, value);
        _addInputs(_inputBox, appContract, payloads);

        uint256 senderBalance = sender.balance;
        uint256 appContractBalance = appContract.balance;

        uint256 numOfInputs = _inputBox.getNumberOfInputs(appContract);

        vm.recordLogs();

        vm.prank(sender);
        _portal.depositEther{value: value}(appContract, execLayerData);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes memory input;
        bytes memory payload;
        uint256 numOfInputAdded;

        for (uint256 i; i < logs.length; ++i) {
            Vm.Log memory log = logs[i];
            if (log.emitter == address(_inputBox)) {
                (input, payload) =
                    _decodeInputAdded(log, appContract, address(_portal), numOfInputs);
                ++numOfInputAdded;
            } else {
                revert("unexpected log emitter");
            }
        }

        assertEq(numOfInputAdded, 1);
        assertEq(sender.balance, senderBalance - value);
        assertEq(appContract.balance, appContractBalance + value);

        assertEq(_inputBox.getNumberOfInputs(appContract), numOfInputs + 1);
        assertEq(keccak256(input), _inputBox.getInputHash(appContract, numOfInputs));

        bytes memory buffer = payload;
        address senderArg;
        uint256 valueArg;
        bytes memory execLayerDataArg;

        (senderArg, buffer) = buffer.consumeAddress();
        (valueArg, execLayerDataArg) = buffer.consumeUint256();

        assertEq(senderArg, sender);
        assertEq(valueArg, value);
        assertEq(execLayerDataArg, execLayerData);
    }

    function _randomSetup(address sender, address appContract, uint256 value) internal {
        // Mine a random number of blocks
        vm.roll(vm.randomUint(vm.getBlockNumber(), type(uint256).max));

        // Transfer a random amount of Ether to each participant
        vm.deal(sender, vm.randomUint(value, type(uint256).max));
        vm.deal(address(_portal), vm.randomUint(0, type(uint256).max - value));
        vm.deal(appContract, vm.randomUint(0, type(uint256).max - value));
    }
}
