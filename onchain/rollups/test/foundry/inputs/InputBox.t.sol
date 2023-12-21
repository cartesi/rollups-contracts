// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {InputBox} from "contracts/inputs/InputBox.sol";
import {IInputBox} from "contracts/inputs/IInputBox.sol";
import {CanonicalMachine} from "contracts/common/CanonicalMachine.sol";
import {LibInput} from "contracts/library/LibInput.sol";

contract InputBoxTest is Test {
    InputBox _inputBox;

    function setUp() public {
        _inputBox = new InputBox();
    }

    function testNoInputs(address app) public {
        assertEq(_inputBox.getNumberOfInputs(app), 0);
    }

    function testAddLargeInput() public {
        address app = vm.addr(1);
        uint256 max = CanonicalMachine.INPUT_PAYLOAD_MAX_SIZE;

        _inputBox.addInput(app, new bytes(max));

        vm.expectRevert(
            abi.encodeWithSelector(
                IInputBox.PayloadTooLarge.selector,
                app,
                max + 1,
                max
            )
        );
        _inputBox.addInput(app, new bytes(max + 1));
    }

    function testAddInput(address app, bytes[] calldata inputs) public {
        uint256 numInputs = inputs.length;
        bytes32[] memory returnedValues = new bytes32[](numInputs);
        uint256 year2022 = 1641070800; // Unix Timestamp for 2022

        // assume #bytes for each input is within bounds
        for (uint256 i; i < numInputs; ++i) {
            vm.assume(
                inputs[i].length <= CanonicalMachine.INPUT_PAYLOAD_MAX_SIZE
            );
        }

        // adding inputs
        for (uint256 i; i < numInputs; ++i) {
            // test for different block number and timestamp
            vm.roll(i);
            vm.warp(i + year2022);

            vm.expectEmit(true, true, false, true, address(_inputBox));
            emit IInputBox.InputAdded(app, i, address(this), inputs[i]);

            returnedValues[i] = _inputBox.addInput(app, inputs[i]);

            assertEq(i + 1, _inputBox.getNumberOfInputs(app));
        }

        // testing added inputs
        for (uint256 i; i < numInputs; ++i) {
            bytes32 inputHash = LibInput.computeInputHash(
                address(this),
                i, // block.number
                i + year2022, // block.timestamp
                i, // index
                inputs[i]
            );
            // test if input hash is the same as in InputBox
            assertEq(inputHash, _inputBox.getInputHash(app, i));
            // test if input hash is the same as returned from calling addInput() function
            assertEq(inputHash, returnedValues[i]);
        }
    }
}
