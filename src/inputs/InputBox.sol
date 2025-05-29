// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.18;

import {IInputBox} from "./IInputBox.sol";
import {CanonicalMachine} from "../common/CanonicalMachine.sol";
import {Inputs} from "../common/Inputs.sol";
import {LibMerkle} from "../library/LibMerkle.sol";

contract InputBox is IInputBox {
    using LibMerkle for bytes;
    using LibMerkle for uint256;

    /// @notice Deployment block number
    uint256 immutable _deploymentBlockNumber = block.number;

    /// @notice An input box entry
    /// @param inputHash The input hash (using keccak256)
    /// @param inputMerkleRoot The input Merkle root (using 32-byte leaves
    /// and the smallest Merkle tree that fits the whole input, padded with zeroes).
    struct InputBoxEntry {
        bytes32 inputHash;
        bytes32 inputMerkleRoot;
    }

    /// @notice Mapping of application contract addresses to arrays of input hashes.
    mapping(address => InputBoxEntry[]) private _inputBoxes;

    /// @inheritdoc IInputBox
    function addInput(address appContract, bytes calldata payload)
        external
        override
        returns (bytes32)
    {
        InputBoxEntry[] storage inputBox = _inputBoxes[appContract];

        uint256 index = inputBox.length;

        bytes memory input = abi.encodeCall(
            Inputs.EvmAdvance,
            (
                block.chainid,
                appContract,
                msg.sender,
                block.number,
                block.timestamp,
                block.prevrandao,
                index,
                payload
            )
        );

        if (input.length > CanonicalMachine.INPUT_MAX_SIZE) {
            revert InputTooLarge(
                appContract, input.length, CanonicalMachine.INPUT_MAX_SIZE
            );
        }

        bytes32 inputHash = keccak256(input);

        uint256 log2SizeOfDrive = input.length.getMinLog2SizeOfDrive();
        bytes32 inputMerkleRoot = input.getMerkleRootFromBytes(log2SizeOfDrive);

        inputBox.push(
            InputBoxEntry({inputHash: inputHash, inputMerkleRoot: inputMerkleRoot})
        );

        emit InputAdded(appContract, index, input);

        return inputHash;
    }

    /// @inheritdoc IInputBox
    function getNumberOfInputs(address appContract)
        external
        view
        override
        returns (uint256)
    {
        return _inputBoxes[appContract].length;
    }

    /// @inheritdoc IInputBox
    function getInputHash(address appContract, uint256 index)
        external
        view
        override
        returns (bytes32)
    {
        return _inputBoxes[appContract][index].inputHash;
    }

    /// @inheritdoc IInputBox
    function getInputMerkleRoot(address appContract, uint256 index)
        external
        view
        override
        returns (bytes32)
    {
        return _inputBoxes[appContract][index].inputMerkleRoot;
    }

    /// @inheritdoc IInputBox
    function getDeploymentBlockNumber() external view override returns (uint256) {
        return _deploymentBlockNumber;
    }
}
