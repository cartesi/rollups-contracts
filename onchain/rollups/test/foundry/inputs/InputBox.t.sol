// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Input Box Test
pragma solidity ^0.8.8;

import {Test} from "forge-std/Test.sol";
import {InputBox} from "contracts/inputs/InputBox.sol";
import {IInputBox} from "contracts/inputs/IInputBox.sol";
import {CanonicalMachine} from "contracts/common/CanonicalMachine.sol";
import {LibInput} from "contracts/library/LibInput.sol";

contract InputBoxHandler is Test {
    IInputBox immutable inputBox;

    struct InputData {
        address app;
        uint256 index;
        bytes32 inputHash;
    }

    InputData[] inputDataArray;

    // array of addresses of applications whose input boxes aren't empty
    address[] apps;

    // mapping of application addresses to number of inputs
    mapping(address => uint256) numOfInputs;

    // block variables
    uint256 blockTimestamp = block.timestamp;
    uint256 blockNumber = block.number;

    constructor(IInputBox _inputBox) {
        inputBox = _inputBox;
    }

    function incrementBlockTimestamp() external {
        blockTimestamp++;
    }

    function incrementBlockNumber() external {
        blockNumber++;
    }

    function setBlockProperties() internal {
        vm.warp(blockTimestamp);
        vm.roll(blockNumber);
    }

    function addInput(address _app, bytes calldata _input) external {
        // For some reason, the invariant testing framework doesn't
        // record changes made to block properties, so we have to
        // set them in the beginning of every call
        setBlockProperties();

        // Get the index of the to-be-added input
        uint256 index = inputBox.getNumberOfInputs(_app);

        // Check if `getNumberOfInputs` matches internal count
        assertEq(index, numOfInputs[_app], "input box size");

        // Make the sender add the input to the application's input box
        vm.prank(msg.sender);
        bytes32 inputHash = inputBox.addInput(_app, _input);

        // If this is the first input being added to the application's input box,
        // then push the application to the array of applications
        if (index == 0) {
            apps.push(_app);
        }

        // Increment the application's input count
        ++numOfInputs[_app];

        // Create the input data struct
        InputData memory inputData = InputData({
            app: _app,
            index: index,
            inputHash: inputHash
        });

        // Add the input data to the array
        inputDataArray.push(inputData);

        // Check if the input box size increases by one
        assertEq(
            index + 1,
            inputBox.getNumberOfInputs(_app),
            "input box size increment"
        );

        // Check if the input hash matches the one returned by `getInputHash`
        assertEq(
            inputHash,
            inputBox.getInputHash(_app, index),
            "returned input hash"
        );

        // Compute the input hash from the arguments passed to `addInput`
        bytes32 computedInputHash = LibInput.computeInputHash(
            msg.sender,
            block.number,
            block.timestamp,
            _input,
            index
        );

        // Check if the input hash matches the computed one
        assertEq(inputHash, computedInputHash, "computed input hash");
    }

    function getTotalNumberOfInputs() external view returns (uint256) {
        return inputDataArray.length;
    }

    function getInputAt(uint256 _i) external view returns (InputData memory) {
        return inputDataArray[_i];
    }

    function getNumberOfApplications() external view returns (uint256) {
        return apps.length;
    }

    function getApplicationAt(uint256 _i) external view returns (address) {
        return apps[_i];
    }

    function getNumberOfInputs(address _app) external view returns (uint256) {
        return numOfInputs[_app];
    }
}

contract InputBoxTest is Test {
    using CanonicalMachine for CanonicalMachine.Log2Size;

    InputBox inputBox;
    InputBoxHandler handler;

    event InputAdded(
        address indexed app,
        uint256 indexed inputIndex,
        address sender,
        bytes input
    );

    function setUp() public {
        inputBox = new InputBox();
        handler = new InputBoxHandler(inputBox);

        // for the invariant testing,
        // don't call the input box contract directly
        // (do it through the handler contract)
        excludeContract(address(inputBox));
    }

    function testNoInputs(address _app) public {
        assertEq(inputBox.getNumberOfInputs(_app), 0);
    }

    function testAddLargeInput() public {
        address app = vm.addr(1);

        inputBox.addInput(app, new bytes(CanonicalMachine.INPUT_MAX_SIZE));

        vm.expectRevert(LibInput.InputSizeExceedsLimit.selector);
        inputBox.addInput(app, new bytes(CanonicalMachine.INPUT_MAX_SIZE + 1));
    }

    // fuzz testing with multiple inputs
    function testAddInput(address _app, bytes[] calldata _inputs) public {
        uint256 numInputs = _inputs.length;
        bytes32[] memory returnedValues = new bytes32[](numInputs);
        uint256 year2022 = 1641070800; // Unix Timestamp for 2022

        // assume #bytes for each input is within bounds
        for (uint256 i; i < numInputs; ++i) {
            vm.assume(_inputs[i].length <= CanonicalMachine.INPUT_MAX_SIZE);
        }

        // adding inputs
        for (uint256 i; i < numInputs; ++i) {
            // test for different block number and timestamp
            vm.roll(i);
            vm.warp(i + year2022); // year 2022

            // topics 1 and 2 are indexed; topic 3 isn't; check event data
            vm.expectEmit(true, true, false, true, address(inputBox));

            // The event we expect
            emit InputAdded(_app, i, address(this), _inputs[i]);

            returnedValues[i] = inputBox.addInput(_app, _inputs[i]);

            // test whether the number of inputs has increased
            assertEq(i + 1, inputBox.getNumberOfInputs(_app));
        }

        // testing added inputs
        for (uint256 i; i < numInputs; ++i) {
            // compute input hash for each input
            bytes32 inputHash = LibInput.computeInputHash(
                address(this),
                i, // block.number
                i + year2022, // block.timestamp
                _inputs[i],
                i // inputBox.length
            );
            // test if input hash is the same as in InputBox
            assertEq(inputHash, inputBox.getInputHash(_app, i));
            // test if input hash is the same as returned from calling addInput() function
            assertEq(inputHash, returnedValues[i]);
        }
    }

    function invariantInputData() external {
        // Get the total number of inputs
        uint256 totalNumOfInputs = handler.getTotalNumberOfInputs();

        for (uint256 i; i < totalNumOfInputs; ++i) {
            // Get input data and metadata passed to `addInput`
            InputBoxHandler.InputData memory inputData = handler.getInputAt(i);

            // Make sure the input index is less than the input box size
            assertLt(
                inputData.index,
                inputBox.getNumberOfInputs(inputData.app),
                "index bound check"
            );

            // Get the input hash returned by `getInputHash`
            bytes32 inputHash = inputBox.getInputHash(
                inputData.app,
                inputData.index
            );

            // Check if the input hash matches the one returned by `addInput`
            assertEq(inputHash, inputData.inputHash, "returned input hash");
        }

        // Get the number of applications in the array
        uint256 numOfApplications = handler.getNumberOfApplications();

        // Check the input box size of all the applications that
        // were interacted with, and sum them all up
        uint256 sum;
        for (uint256 i; i < numOfApplications; ++i) {
            address app = handler.getApplicationAt(i);
            uint256 expected = handler.getNumberOfInputs(app);
            uint256 actual = inputBox.getNumberOfInputs(app);
            assertEq(expected, actual, "number of inputs for app");
            sum += actual;
        }
        assertEq(sum, totalNumOfInputs, "total number of inputs");
    }
}
