// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IInputBox} from "./IInputBox.sol";
import {LibInput} from "../library/LibInput.sol";
import {CanonicalMachine} from "../common/CanonicalMachine.sol";

contract InputBox is IInputBox {
    /// @notice Mapping of application addresses to arrays of input hashes.
    mapping(address => bytes32[]) private _inputBoxes;

    /// @inheritdoc IInputBox
    function addInput(
        address app,
        bytes calldata payload
    ) external override returns (bytes32) {
        if (payload.length > CanonicalMachine.INPUT_PAYLOAD_MAX_SIZE) {
            revert PayloadTooLarge(
                app,
                payload.length,
                CanonicalMachine.INPUT_PAYLOAD_MAX_SIZE
            );
        }

        bytes32[] storage inputBox = _inputBoxes[app];

        uint256 index = inputBox.length;

        bytes32 inputHash = LibInput.computeInputHash(
            msg.sender,
            block.number,
            block.timestamp,
            index,
            payload
        );

        inputBox.push(inputHash);

        emit InputAdded(app, index, msg.sender, payload);

        return inputHash;
    }

    /// @inheritdoc IInputBox
    function getNumberOfInputs(
        address app
    ) external view override returns (uint256) {
        return _inputBoxes[app].length;
    }

    /// @inheritdoc IInputBox
    function getInputHash(
        address app,
        uint256 index
    ) external view override returns (bytes32) {
        return _inputBoxes[app][index];
    }
}
