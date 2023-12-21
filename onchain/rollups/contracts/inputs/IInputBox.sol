// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

/// @notice Provides data availability of inputs for applications.
/// @notice Each application has its own append-only list of inputs.
/// @notice Off-chain, inputs can be reconstructed from events.
/// @notice On-chain, only the input hashes are stored.
/// @notice See `LibInput` for more details on how such hashes are computed.
interface IInputBox {
    /// @notice MUST trigger when an input is added.
    /// @param app The application address
    /// @param index The input index
    /// @param sender The input sender address
    /// @param payload The input payload
    event InputAdded(
        address indexed app,
        uint256 indexed index,
        address sender,
        bytes payload
    );

    /// @notice Payload is too large.
    /// @param app The application address
    /// @param payloadLength The payload length
    /// @param maxPayloadLength The maximum payload length
    error PayloadTooLarge(
        address app,
        uint256 payloadLength,
        uint256 maxPayloadLength
    );

    /// @notice Send an input to an application.
    /// @param app The application address
    /// @param payload The input payload
    /// @return The input hash
    /// @dev MUST fire an `InputAdded` event.
    function addInput(
        address app,
        bytes calldata payload
    ) external returns (bytes32);

    /// @notice Get the number of inputs sent to an application.
    /// @param app The application address
    function getNumberOfInputs(address app) external view returns (uint256);

    /// @notice Get the hash of an input in an application's input box.
    /// @param app The application address
    /// @param index The input index
    /// @dev The provided index must be valid.
    function getInputHash(
        address app,
        uint256 index
    ) external view returns (bytes32);
}
