// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {InputBox} from "contracts/inputs/InputBox.sol";
import {IInputBox} from "contracts/inputs/IInputBox.sol";
import {CanonicalMachine} from "contracts/common/CanonicalMachine.sol";
import {LibInput} from "contracts/library/LibInput.sol";

contract InputBoxTest is Test {
    InputBox inputBox;

    function setUp() public {
        inputBox = new InputBox();
    }

    function testNoInputs(address dapp) public {
        assertEq(inputBox.getNumberOfInputs(dapp), 0);
    }

    function testAddLargeInput() public {
        address dapp = vm.addr(1);

        inputBox.addInput(dapp, new bytes(CanonicalMachine.INPUT_MAX_SIZE));

        vm.expectRevert("InputBox: payload too large");
        inputBox.addInput(dapp, new bytes(CanonicalMachine.INPUT_MAX_SIZE + 1));
    }

    function testAddInput(address dapp, bytes[] calldata inputs) public {
        uint256 numInputs = inputs.length;
        bytes32[] memory returnedValues = new bytes32[](numInputs);
        uint256 year2022 = 1641070800; // Unix Timestamp for 2022

        // assume #bytes for each input is within bounds
        for (uint256 i; i < numInputs; ++i) {
            vm.assume(inputs[i].length <= CanonicalMachine.INPUT_MAX_SIZE);
        }

        // adding inputs
        for (uint256 i; i < numInputs; ++i) {
            // test for different block number and timestamp
            vm.roll(i);
            vm.warp(i + year2022);

            vm.expectEmit(true, true, false, true, address(inputBox));
            emit IInputBox.InputAdded(dapp, i, address(this), inputs[i]);

            returnedValues[i] = inputBox.addInput(dapp, inputs[i]);

            assertEq(i + 1, inputBox.getNumberOfInputs(dapp));
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
            assertEq(inputHash, inputBox.getInputHash(dapp, i));
            // test if input hash is the same as returned from calling addInput() function
            assertEq(inputHash, returnedValues[i]);
        }
    }
}
