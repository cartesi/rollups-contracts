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

    function testNoInputs(address appContract) public view {
        assertEq(_inputBox.getNumberOfInputs(appContract), 0);
        assertEq(_inputBox.getNumberOfInputsBeforeCurrentBlock(appContract), 0);
    }

    function testAddLargeInput() public {
        address appContract = vm.addr(1);
        uint256 max = _getMaxInputPayloadLength();

        _inputBox.addInput(appContract, new bytes(max));

        bytes memory largePayload = new bytes(max + 1);
        uint256 largeLength = EvmAdvanceEncoder
            .encode(1, appContract, address(this), 1, largePayload)
            .length;
        vm.expectRevert(
            abi.encodeWithSelector(
                IInputBox.InputTooLarge.selector,
                appContract,
                largeLength,
                CanonicalMachine.INPUT_MAX_SIZE
            )
        );
        _inputBox.addInput(appContract, largePayload);
    }

    function testAddInput(
        uint64 chainId,
        address appContract,
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
            vm.prevrandao(bytes32(_prevrandao(i)));

            vm.expectEmit(true, true, false, true, address(_inputBox));
            bytes memory input = EvmAdvanceEncoder.encode(
                chainId,
                appContract,
                address(this),
                i,
                payloads[i]
            );
            emit IInputBox.InputAdded(appContract, i, input);

            returnedValues[i] = _inputBox.addInput(appContract, payloads[i]);

            assertEq(i + 1, _inputBox.getNumberOfInputs(appContract));
        }

        // testing added inputs
        for (uint256 i; i < numPayloads; ++i) {
            bytes32 inputHash = keccak256(
                abi.encodeCall(
                    Inputs.EvmAdvance,
                    (
                        chainId,
                        appContract,
                        address(this),
                        i, // block.number
                        i + year2022, // block.timestamp
                        _prevrandao(i), // block.prevrandao
                        i, // inputBox.length
                        payloads[i]
                    )
                )
            );
            // test if input hash is the same as in InputBox
            assertEq(inputHash, _inputBox.getInputHash(appContract, i));
            // test if input hash is the same as returned from calling addInput() function
            assertEq(inputHash, returnedValues[i]);
        }
    }

    function testNumberOfInputsBeforeCurrentBlock() external {
        address appContract = vm.addr(1);
        for (uint256 j; j < 3; ++j) {
            uint256 n = _inputBox.getNumberOfInputs(appContract);
            for (uint256 i; i < 2; ++i) {
                _inputBox.addInput(appContract, new bytes(0));
                // prettier-ignore
                assertEq(_inputBox.getNumberOfInputsBeforeCurrentBlock(appContract), n);
            }
            vm.roll(vm.getBlockNumber() + 1);
        }
    }

    function _prevrandao(uint256 blockNumber) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode("prevrandao", blockNumber)));
    }

    function _getMaxInputPayloadLength() internal pure returns (uint256) {
        bytes memory blob = abi.encodeCall(
            Inputs.EvmAdvance,
            (0, address(0), address(0), 0, 0, 0, 0, new bytes(32))
        );
        // number of bytes in input blob excluding input payload
        uint256 extraBytes = blob.length - 32;
        // because it's abi encoded, input payloads are stored as multiples of 32 bytes
        return ((CanonicalMachine.INPUT_MAX_SIZE - extraBytes) / 32) * 32;
    }
}
