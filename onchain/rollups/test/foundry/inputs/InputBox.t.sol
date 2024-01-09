// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Input Box Test
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {InputBox} from "contracts/inputs/InputBox.sol";
import {IInputBox} from "contracts/inputs/IInputBox.sol";
import {CanonicalMachine} from "contracts/common/CanonicalMachine.sol";
import {LibInput} from "contracts/library/LibInput.sol";

contract InputBoxHandler is Test {
    struct InputData {
        address app;
        uint256 index;
        bytes32 inputHash;
    }

    IInputBox immutable _inputBox;
    InputData[] _inputDataArray;

    // array of addresses of applications whose input boxes aren't empty
    address[] _apps;
    // mapping of application addresses to number of inputs
    mapping(address => uint256) _numOfInputs;
    // block variables
    uint256 _blockTimestamp = block.timestamp;
    uint256 _blockNumber = block.number;

    constructor(IInputBox inputBox) {
        _inputBox = inputBox;
    }

    function incrementBlockTimestamp() external {
        _blockTimestamp++;
    }

    function incrementBlockNumber() external {
        _blockNumber++;
    }

    function _setBlockProperties() internal {
        vm.warp(_blockTimestamp);
        vm.roll(_blockNumber);
    }

    function addInput(address app, bytes calldata input) external {
        // For some reason, the invariant testing framework doesn't
        // record changes made to block properties, so we have to
        // set them in the beginning of every call
        _setBlockProperties();

        // Get the index of the to-be-added input
        uint256 index = _inputBox.getNumberOfInputs(app);

        // Check if `getNumberOfInputs` matches internal count
        assertEq(index, _numOfInputs[app], "input box size");

        // Make the sender add the input to the application's input box
        vm.prank(msg.sender);
        bytes32 inputHash = _inputBox.addInput(app, input);

        // If this is the first input being added to the application's input box,
        // then push the application to the array of applications
        if (index == 0) {
            _apps.push(app);
        }

        // Increment the application's input count
        ++_numOfInputs[app];

        // Create the input data struct
        InputData memory inputData = InputData({
            app: app,
            index: index,
            inputHash: inputHash
        });

        // Add the input data to the array
        _inputDataArray.push(inputData);

        // Check if the input box size increases by one
        assertEq(
            index + 1,
            _inputBox.getNumberOfInputs(app),
            "input box size increment"
        );

        // Check if the input hash matches the one returned by `getInputHash`
        assertEq(
            inputHash,
            _inputBox.getInputHash(app, index),
            "returned input hash"
        );

        // Compute the input hash from the arguments passed to `addInput`
        bytes32 computedInputHash = LibInput.computeInputHash(
            msg.sender,
            block.number,
            block.timestamp,
            input,
            index
        );

        // Check if the input hash matches the computed one
        assertEq(inputHash, computedInputHash, "computed input hash");
    }

    function getTotalNumberOfInputs() external view returns (uint256) {
        return _inputDataArray.length;
    }

    function getInputAt(uint256 i) external view returns (InputData memory) {
        return _inputDataArray[i];
    }

    function getNumberOfApplications() external view returns (uint256) {
        return _apps.length;
    }

    function getApplicationAt(uint256 i) external view returns (address) {
        return _apps[i];
    }

    function getNumberOfInputs(address app) external view returns (uint256) {
        return _numOfInputs[app];
    }
}

contract InputBoxTest is Test {
    using CanonicalMachine for CanonicalMachine.Log2Size;

    InputBox _inputBox;
    InputBoxHandler _handler;

    function setUp() public {
        _inputBox = new InputBox();
        _handler = new InputBoxHandler(_inputBox);

        // for the invariant testing,
        // don't call the input box contract directly
        // (do it through the handler contract)
        excludeContract(address(_inputBox));
    }

    function testNoInputs(address app) public {
        assertEq(_inputBox.getNumberOfInputs(app), 0);
    }

    function testAddLargeInput() public {
        address app = vm.addr(1);

        _inputBox.addInput(app, new bytes(CanonicalMachine.INPUT_MAX_SIZE));

        vm.expectRevert(LibInput.InputSizeExceedsLimit.selector);
        _inputBox.addInput(app, new bytes(CanonicalMachine.INPUT_MAX_SIZE + 1));
    }

    // fuzz testing with multiple inputs
    function testAddInput(address app, bytes[] calldata inputs) public {
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
            vm.warp(i + year2022); // year 2022

            // topics 1 and 2 are indexed; topic 3 isn't; check event data
            vm.expectEmit(true, true, false, true, address(_inputBox));

            // The event we expect
            emit IInputBox.InputAdded(app, i, address(this), inputs[i]);

            returnedValues[i] = _inputBox.addInput(app, inputs[i]);

            // test whether the number of inputs has increased
            assertEq(i + 1, _inputBox.getNumberOfInputs(app));
        }

        // testing added inputs
        for (uint256 i; i < numInputs; ++i) {
            // compute input hash for each input
            bytes32 inputHash = LibInput.computeInputHash(
                address(this),
                i, // block.number
                i + year2022, // block.timestamp
                inputs[i],
                i // inputBox.length
            );
            // test if input hash is the same as in InputBox
            assertEq(inputHash, _inputBox.getInputHash(app, i));
            // test if input hash is the same as returned from calling addInput() function
            assertEq(inputHash, returnedValues[i]);
        }
    }

    function invariantInputData() external {
        // Get the total number of inputs
        uint256 totalNumOfInputs = _handler.getTotalNumberOfInputs();

        for (uint256 i; i < totalNumOfInputs; ++i) {
            // Get input data and metadata passed to `addInput`
            InputBoxHandler.InputData memory inputData = _handler.getInputAt(i);

            // Make sure the input index is less than the input box size
            assertLt(
                inputData.index,
                _inputBox.getNumberOfInputs(inputData.app),
                "index bound check"
            );

            // Get the input hash returned by `getInputHash`
            bytes32 inputHash = _inputBox.getInputHash(
                inputData.app,
                inputData.index
            );

            // Check if the input hash matches the one returned by `addInput`
            assertEq(inputHash, inputData.inputHash, "returned input hash");
        }

        // Get the number of applications in the array
        uint256 numOfApplications = _handler.getNumberOfApplications();

        // Check the input box size of all the applications that
        // were interacted with, and sum them all up
        uint256 sum;
        for (uint256 i; i < numOfApplications; ++i) {
            address app = _handler.getApplicationAt(i);
            uint256 expected = _handler.getNumberOfInputs(app);
            uint256 actual = _inputBox.getNumberOfInputs(app);
            assertEq(expected, actual, "number of inputs for app");
            sum += actual;
        }
        assertEq(sum, totalNumOfInputs, "total number of inputs");
    }
}
