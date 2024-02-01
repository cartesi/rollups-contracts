// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {InputBox} from "contracts/inputs/InputBox.sol";
import {IInputBox} from "contracts/inputs/IInputBox.sol";
import {CanonicalMachine} from "contracts/common/CanonicalMachine.sol";
import {Inputs} from "contracts/common/Inputs.sol";

import {EvmAdvanceEncoder} from "../util/EvmAdvanceEncoder.sol";

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
        uint256 max = _getMaxInputPayloadLength();

        _inputBox.addInput(app, new bytes(max));

        bytes memory largePayload = new bytes(max + 1);
        uint256 largeLength = EvmAdvanceEncoder
            .encode(1, app, address(this), 1, largePayload)
            .length;
        vm.expectRevert(
            abi.encodeWithSelector(
                IInputBox.InputTooLarge.selector,
                app,
                largeLength,
                CanonicalMachine.INPUT_MAX_SIZE
            )
        );
        _inputBox.addInput(app, largePayload);
    }

    function testAddInput(
        uint64 chainId,
        address app,
        bytes[] calldata payloads
    ) public {
        vm.chainId(chainId); // foundry limits chain id to be less than 2^64 - 1

        uint256 numPayloads = payloads.length;
        bytes32[] memory returnedValues = new bytes32[](numPayloads);
        uint256 year2022 = 1641070800; // Unix Timestamp for 2022

        // assume #bytes for each payload is within bounds
        for (uint256 i; i < numPayloads; ++i) {
            vm.assume(payloads[i].length <= _getMaxInputPayloadLength());
        }

        // adding inputs
        for (uint256 i; i < numPayloads; ++i) {
            // test for different block number and timestamp
            vm.roll(i);
            vm.warp(i + year2022);

            vm.expectEmit(true, true, false, true, address(_inputBox));
            bytes memory input = EvmAdvanceEncoder.encode(
                chainId,
                app,
                address(this),
                i,
                payloads[i]
            );
            emit IInputBox.InputAdded(app, i, input);

            returnedValues[i] = _inputBox.addInput(app, payloads[i]);

            assertEq(i + 1, _inputBox.getNumberOfInputs(app));
        }

        // testing added inputs
        for (uint256 i; i < numPayloads; ++i) {
            bytes32 inputHash = keccak256(
                abi.encodeCall(
                    Inputs.EvmAdvance,
                    (
                        chainId,
                        app,
                        address(this),
                        i, // block.number
                        i + year2022, // block.timestamp
                        i, // inputBox.length
                        payloads[i]
                    )
                )
            );
            // test if input hash is the same as in InputBox
            assertEq(inputHash, _inputBox.getInputHash(app, i));
            // test if input hash is the same as returned from calling addInput() function
            assertEq(inputHash, returnedValues[i]);
        }
    }

    function _getMaxInputPayloadLength() internal pure returns (uint256) {
        bytes memory blob = abi.encodeCall(
            Inputs.EvmAdvance,
            (0, address(0), address(0), 0, 0, 0, new bytes(32))
        );
        // number of bytes in input blob excluding input payload
        uint256 extraBytes = blob.length - 32;
        // because it's abi encoded, input payloads are stored as multiples of 32 bytes
        return ((CanonicalMachine.INPUT_MAX_SIZE - extraBytes) / 32) * 32;
    }
}
