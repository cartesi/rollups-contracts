// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IInputBox} from "./IInputBox.sol";
import {LibInput} from "../library/LibInput.sol";

/// @title Input Box
///
/// @notice Trustless and permissionless contract that receives arbitrary blobs
/// (called "inputs") from anyone and adds a compound hash to an append-only list
/// (called "input box"). Each application has its own input box.
///
/// The hash that is stored on-chain is composed by the hash of the input blob,
/// the block number and timestamp, the input sender address, and the input index.
///
/// Data availability is guaranteed by the emission of `InputAdded` events
/// on every successful call to `addInput`. This ensures that inputs can be
/// retrieved by anyone at any time, without having to rely on centralized data
/// providers.
///
/// From the perspective of this contract, inputs are encoding-agnostic byte
/// arrays. It is up to the application to interpret, validate and act upon inputs.
contract InputBox is IInputBox {
    /// @notice Mapping from application address to list of input hashes.
    /// @dev See the `getNumberOfInputs`, `getInputHash` and `addInput` functions.
    mapping(address => bytes32[]) internal _inputBoxes;

    function addInput(
        address app,
        bytes calldata input
    ) external override returns (bytes32) {
        bytes32[] storage inputBox = _inputBoxes[app];
        uint256 inputIndex = inputBox.length;

        bytes32 inputHash = LibInput.computeInputHash(
            msg.sender,
            block.number,
            block.timestamp,
            input,
            inputIndex
        );

        // add input to the input box
        inputBox.push(inputHash);

        // block.number and timestamp can be retrieved by the event metadata itself
        emit InputAdded(app, inputIndex, msg.sender, input);

        return inputHash;
    }

    function getNumberOfInputs(
        address app
    ) external view override returns (uint256) {
        return _inputBoxes[app].length;
    }

    function getInputHash(
        address app,
        uint256 index
    ) external view override returns (bytes32) {
        return _inputBoxes[app][index];
    }
}
