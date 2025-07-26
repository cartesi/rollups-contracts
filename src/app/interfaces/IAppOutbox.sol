// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {OutputValidityProof} from "../../common/OutputValidityProof.sol";

/// @notice Allows the validation and execution of outputs.
interface IAppOutbox {
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

    /// @notice Raised when the output hashes siblings array has an invalid size.
    /// @dev Please consult `CanonicalMachine` for the maximum number of outputs.
    error InvalidOutputHashesSiblingsArrayLength();

    /// @notice Raised when the computed outputs Merkle root is invalid.
    error InvalidOutputsMerkleRoot(bytes32 outputsMerkleRoot);

    /// @notice Get number of outputs that have been executed.
    function getNumberOfExecutedOutputs() external view returns (uint256);

    /// @notice Check whether an output has been executed.
    /// @param outputIndex The index of output
    /// @return Whether the output has been executed before
    function wasOutputExecuted(uint256 outputIndex) external view returns (bool);

    /// @notice Validate an output hash.
    /// @param outputHash The output hash
    /// @param proof The proof used to validate the output against
    ///              a claim accepted to the current outputs Merkle root validator contract
    /// @dev May raise `InvalidOutputHashesSiblingsArrayLength`
    /// or `InvalidOutputsMerkleRoot`.
    function validateOutputHash(bytes32 outputHash, OutputValidityProof calldata proof)
        external
        view;

    /// @notice Validate an output.
    /// @param output The output
    /// @param proof The proof used to validate the output against
    ///              a claim accepted to the current outputs Merkle root validator contract
    /// @dev May raise any of the errors raised by `validateOutputHash`.
    function validateOutput(bytes calldata output, OutputValidityProof calldata proof)
        external
        view;

    /// @notice Execute an output.
    /// @param output The output
    /// @param proof The proof used to validate the output against
    ///              a claim accepted to the current outputs Merkle root validator contract
    /// @dev On a successful execution, emits a `OutputExecuted` event.
    /// @dev May raise any of the errors raised by `validateOutput`,
    /// as well as `OutputNotExecutable` and `OutputNotReexecutable`.
    function executeOutput(bytes calldata output, OutputValidityProof calldata proof)
        external;
}
