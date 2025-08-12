// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Test} from "forge-std-1.9.6/src/Test.sol";

import {Create2} from "@openzeppelin-contracts-5.2.0/utils/Create2.sol";

import {InputBox} from "src/inputs/InputBox.sol";
import {IInputBox} from "src/inputs/IInputBox.sol";
import {CanonicalMachine} from "src/common/CanonicalMachine.sol";
import {Inputs} from "src/common/Inputs.sol";
import {LibBinaryMerkleTree} from "src/library/LibBinaryMerkleTree.sol";
import {LibKeccak256} from "src/library/LibKeccak256.sol";
import {LibMath} from "src/library/LibMath.sol";

import {EvmAdvanceEncoder} from "../util/EvmAdvanceEncoder.sol";
import {MockContract} from "../util/MockContract.sol";

contract InputBoxTest is Test {
    using LibMath for uint256;
    using LibBinaryMerkleTree for bytes;

    InputBox _inputBox;

    function setUp() public {
        _inputBox = new InputBox();
    }

    function testDeploymentBlockNumber(uint256 blockNumber) public {
        vm.roll(blockNumber);
        _inputBox = new InputBox();
        assertEq(_inputBox.getDeploymentBlockNumber(), blockNumber);
    }

    function testNoInputs(address appContract) public view {
        assertEq(_inputBox.getNumberOfInputs(appContract), 0);
    }

    function testAddInputNoContract(
        uint256 privateKey,
        bytes32 salt,
        bytes calldata payload
    ) external {
        privateKey = boundPrivateKey(privateKey);

        _testAddInputNoContract(address(0), payload);
        _testAddInputNoContract(vm.addr(privateKey), payload);

        bytes32 bytecodeHash = keccak256(type(MockContract).creationCode);
        address appContract = Create2.computeAddress(salt, bytecodeHash);
        _testAddInputNoContract(appContract, payload);

        assertEq(appContract, address(new MockContract{salt: salt}()));
        assertGt(appContract.code.length, 0);
        _inputBox.addInput(appContract, payload);
    }

    function testAddLargeInput() public {
        address appContract = address(new MockContract());
        uint256 max = _getMaxInputPayloadLength();

        _inputBox.addInput(appContract, new bytes(max));

        bytes memory largePayload = new bytes(max + 1);
        bytes memory largeInput =
            EvmAdvanceEncoder.encode(1, appContract, address(this), 1, largePayload);
        uint256 largeLength = largeInput.length;
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

    function testAddInput(uint64 chainId, bytes[] calldata payloads) public {
        address appContract = address(new MockContract());

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
                chainId, appContract, address(this), i, payloads[i]
            );
            emit IInputBox.InputAdded(appContract, i, input);

            returnedValues[i] = _inputBox.addInput(appContract, payloads[i]);

            assertEq(i + 1, _inputBox.getNumberOfInputs(appContract));
        }

        // testing added inputs
        for (uint256 i; i < numPayloads; ++i) {
            bytes memory input = abi.encodeCall(
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
            );

            uint256 log2DataBlockSize = CanonicalMachine.LOG2_DATA_BLOCK_SIZE;
            uint256 log2DriveSize = input.length.ceilLog2().max(log2DataBlockSize);

            bytes32 inputMerkleRoot = input.merkleRoot(
                log2DriveSize,
                log2DataBlockSize,
                LibKeccak256.hashBlock,
                LibKeccak256.hashPair
            );

            // test if input Merkle root is the same as in InputBox
            assertEq(inputMerkleRoot, _inputBox.getInputMerkleRoot(appContract, i));
            // test if input Merkle root is the same as returned from calling addInput() function
            assertEq(inputMerkleRoot, returnedValues[i]);
        }
    }

    function _testAddInputNoContract(address appContract, bytes calldata payload)
        internal
    {
        assertEq(appContract.code.length, 0, "expected account with no code");
        vm.expectRevert(
            abi.encodeWithSelector(
                IInputBox.ApplicationContractNotDeployed.selector, appContract
            )
        );
        _inputBox.addInput(appContract, payload);
    }

    function _prevrandao(uint256 blockNumber) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode("prevrandao", blockNumber)));
    }

    function _getMaxInputPayloadLength() internal pure returns (uint256) {
        bytes memory blob = abi.encodeCall(
            Inputs.EvmAdvance, (0, address(0), address(0), 0, 0, 0, 0, new bytes(32))
        );
        // number of bytes in input blob excluding input payload
        uint256 extraBytes = blob.length - 32;
        // because it's abi encoded, input payloads are stored as multiples of 32 bytes
        return ((CanonicalMachine.INPUT_MAX_SIZE - extraBytes) / 32) * 32;
    }
}
