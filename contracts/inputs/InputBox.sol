// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.18;

import {IInputBox} from "./IInputBox.sol";
import {CanonicalMachine} from "../common/CanonicalMachine.sol";
import {Inputs} from "../common/Inputs.sol";

contract InputBox is IInputBox {
    /// @notice Mapping of application contract addresses to arrays of input hashes.
    mapping(address => bytes32[]) private _inputBoxes;

    /// @notice Snapshot of number of inputs
    struct Snapshot {
        uint256 blockNumber;
        uint256 numberOfInputsBeforeBlock;
    }

    /// @notice Mapping of application contract addresses to snapshot.
    mapping(address => Snapshot) private _snapshots;

    /// @inheritdoc IInputBox
    function addInput(
        address appContract,
        bytes calldata payload
    ) external override returns (bytes32) {
        bytes32[] storage inputBox = _inputBoxes[appContract];

        uint256 index = inputBox.length;

        // take snapshot if first input of block
        Snapshot storage snapshot = _snapshots[appContract];
        if (snapshot.blockNumber < block.number) {
            snapshot.blockNumber = block.number;
            snapshot.numberOfInputsBeforeBlock = index;
        }

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
                appContract,
                input.length,
                CanonicalMachine.INPUT_MAX_SIZE
            );
        }

        bytes32 inputHash = keccak256(input);

        inputBox.push(inputHash);

        emit InputAdded(appContract, index, input);

        return inputHash;
    }

    /// @inheritdoc IInputBox
    function getNumberOfInputs(
        address appContract
    ) public view override returns (uint256) {
        return _inputBoxes[appContract].length;
    }

    /// @inheritdoc IInputBox
    function getNumberOfInputsBeforeCurrentBlock(
        address appContract
    ) external view returns (uint256) {
        Snapshot storage snapshot = _snapshots[appContract];
        if (snapshot.blockNumber == block.number) {
            return snapshot.numberOfInputsBeforeBlock;
        } else {
            // snapshot.blockNumber < block.number
            return getNumberOfInputs(appContract);
        }
    }

    /// @inheritdoc IInputBox
    function getInputHash(
        address appContract,
        uint256 index
    ) external view override returns (bytes32) {
        return _inputBoxes[appContract][index];
    }
}
