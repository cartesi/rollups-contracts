// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Test} from "forge-std-1.9.6/src/Test.sol";
import {Vm} from "forge-std-1.9.6/src/Vm.sol";

import {CanonicalMachine} from "src/common/CanonicalMachine.sol";
import {Inputs} from "src/common/Inputs.sol";
import {IInputBox} from "src/inputs/IInputBox.sol";
import {InputBox} from "src/inputs/InputBox.sol";

import {InputBoxTestUtils} from "../util/InputBoxTestUtils.sol";

contract InputBoxTest is Test, InputBoxTestUtils {
    InputBox _inputBox;

    function setUp() external {
        _inputBox = new InputBox();
    }

    function testDeploymentBlockNumber(uint256 blockNumber) external {
        vm.roll(blockNumber);
        _inputBox = new InputBox();
        assertEq(_inputBox.getDeploymentBlockNumber(), blockNumber);
    }

    function testNoInputs(address appContract) external view {
        assertEq(_inputBox.getNumberOfInputs(appContract), 0);
    }

    function testAddInputRevertsZeroAddress(bytes calldata payload) external {
        address appContract = address(0);
        vm.expectRevert(_encodeApplicationNotDeployed(appContract));
        _inputBox.addInput(appContract, payload);
    }

    function testAddInputRevertsApplicationNotDeployed(bytes calldata payload) external {
        address appContract = _randomAccountWithNoCode();
        vm.expectRevert(_encodeApplicationNotDeployed(appContract));
        _inputBox.addInput(appContract, payload);
    }

    function testAddInputRevertsApplicationReverted(
        bytes calldata error,
        bytes calldata payload
    ) external {
        address appContract = _newAppMockReverts(error);
        vm.expectRevert(_encodeApplicationReverted(appContract, error));
        _inputBox.addInput(appContract, payload);
    }

    function testAddInputRevertsIllSize(bytes calldata data, bytes calldata payload)
        external
    {
        vm.assume(data.length != 32);
        address appContract = _newAppMockReturns(data);
        vm.expectRevert(_encodeIllformedApplicationReturnData(appContract, data));
        _inputBox.addInput(appContract, payload);
    }

    function testAddInputRevertsIllForm(bytes calldata payload) external {
        uint256 returnValue = vm.randomUint(2, type(uint256).max);
        bytes memory data = abi.encode(returnValue);
        address appContract = _newAppMockReturns(data);
        vm.expectRevert(_encodeIllformedApplicationReturnData(appContract, data));
        _inputBox.addInput(appContract, payload);
    }

    function testAddInputForeclosedApp(bytes calldata payload) external {
        address appContract = _newForeclosedAppMock();
        vm.expectRevert(_encodeApplicationForeclosed(appContract));
        _inputBox.addInput(appContract, payload);
    }

    function testAddLargeInput() external {
        address appContract = _newActiveAppMock();

        bytes memory inputWithEmptyPayload = abi.encodeCall(
            Inputs.EvmAdvance,
            (
                block.chainid,
                appContract,
                address(this),
                vm.getBlockNumber(),
                vm.getBlockTimestamp(),
                block.prevrandao,
                0,
                new bytes(0)
            )
        );

        uint256 maxPayloadLength =
            (CanonicalMachine.INPUT_MAX_SIZE - inputWithEmptyPayload.length)
                & ~uint256(0x1f);

        _inputBox.addInput(appContract, new bytes(maxPayloadLength));

        vm.expectRevert(
            abi.encodeWithSelector(
                IInputBox.InputTooLarge.selector,
                appContract,
                inputWithEmptyPayload.length + maxPayloadLength + 32,
                CanonicalMachine.INPUT_MAX_SIZE
            )
        );
        _inputBox.addInput(appContract, new bytes(maxPayloadLength + 1));
    }

    function testAddInputs(bytes[] calldata payloads) external {
        vm.chainId(vm.randomUint(64));
        for (uint256 i; i < payloads.length; ++i) {
            vm.roll(vm.randomUint(vm.getBlockNumber(), type(uint256).max));
            vm.warp(vm.randomUint(vm.getBlockTimestamp(), type(uint256).max));
            vm.prevrandao(vm.randomUint());
            address appContract = _newActiveAppMock();
            address sender = vm.randomAddress();
            uint256 index = _inputBox.getNumberOfInputs(appContract);
            bytes calldata payload = payloads[i];
            vm.recordLogs();
            vm.prank(sender);
            bytes32 inputHash = _inputBox.addInput(appContract, payload);
            Vm.Log[] memory logs = vm.getRecordedLogs();
            uint256 numOfInputAdded;
            for (uint256 j; j < logs.length; ++j) {
                Vm.Log memory log = logs[j];
                if (log.emitter == address(_inputBox)) {
                    (bytes memory decodedInput, bytes memory decodedPayload) =
                        _decodeInputAdded(log, appContract, sender, index);
                    assertEq(decodedPayload, payload);
                    assertEq(keccak256(decodedInput), inputHash);
                    ++numOfInputAdded;
                } else {
                    revert("unexpected log emitter");
                }
            }
            assertEq(numOfInputAdded, 1);
            assertEq(_inputBox.getInputHash(appContract, index), inputHash);
            assertEq(_inputBox.getNumberOfInputs(appContract), index + 1);
        }
    }
}
