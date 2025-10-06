// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {EventEmitter} from "./EventEmitter.sol";
import {OutputValidityProof} from "../../common/OutputValidityProof.sol";

/// @notice Allows the validation and execution of outputs.
interface Outbox is EventEmitter {
    /// @notice MUST trigger when an output is executed.
    /// @param outputIndex The index of the output
    /// @param output The output
    event OutputExecuted(uint64 outputIndex, bytes output);

    /// @notice Could not execute an output, because the application contract doesn't know how to.
    /// @param output The output
    error OutputNotExecutable(bytes output);

    /// @notice Could not execute an output, because it has already been executed.
    /// @param output The output
    error OutputNotReexecutable(bytes output);

    /// @notice Could not execute an output, because the application contract doesn't have enough Ether.
    /// @param value The amount of Wei necessary for the execution of the output
    /// @param balance The current application contract balance
    error InsufficientFunds(uint256 value, uint256 balance);

    /// @notice Could not validate an output, because the output hashes siblings array has an invalid length.
    /// @dev Please consult `CanonicalMachine` for the maximum number of outputs,
    /// which corresponds to the expected length of the output hashes siblings array.
    error InvalidOutputHashesSiblingsArrayLength();

    /// @notice Could not validate an output, because the computed outputs Merkle root is invalid.
    /// @param computedOutputsMerkleRoot The computed outputs Merkle root
    error InvalidOutputsMerkleRoot(bytes32 computedOutputsMerkleRoot);

    /// @notice Get the number of outputs that have been executed.
    /// @dev Outputs can be executed in any order, so do not assume that
    /// all executed outputs have indices smaller than this value.
    function getOutputExecutionCount() external view returns (uint256);

    /// @notice Check whether an output has been executed.
    /// @param outputIndex The output index
    /// @return Whether the output has been executed before
    function wasOutputExecuted(uint256 outputIndex) external view returns (bool);

    /// @notice Validate an output hash.
    /// @param outputHash The output hash
    /// @param proof The proof used to validate the output
    /// @dev MAY raise an `InvalidOutputHashesSiblingsArrayLength` error.
    /// @dev MAY raise an `InvalidOutputsMerkleRoot` error.
    function validateOutputHash(bytes32 outputHash, OutputValidityProof calldata proof)
        external
        view;

    /// @notice Validate an output.
    /// @param output The output
    /// @param proof The proof used to validate the output
    /// @dev MAY raise any of the errors raised by `validateOutputHash`.
    function validateOutput(bytes calldata output, OutputValidityProof calldata proof)
        external
        view;

    /// @notice Execute an output.
    /// @param output The output
    /// @param proof The proof used to validate the output
    /// @dev On a successful execution, emits a `OutputExecuted` event.
    /// @dev MAY raise any of the errors raised by `validateOutput`.
    /// @dev MAY raise an `OutputNotExecutable` error.
    /// @dev MAY raise an `OutputNotReexecutable` error.
    /// @dev May raise any of the errors raised by `validateOutput`.
    /// as well as `OutputNotExecutable` and `OutputNotReexecutable`.
    function executeOutput(bytes calldata output, OutputValidityProof calldata proof)
        external;
}
