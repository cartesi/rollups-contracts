// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

/// @notice Provides data availability of inputs for applications.
/// @notice Each application has its own append-only list of inputs.
/// @notice Off-chain, inputs can be retrieved via events.
/// @notice On-chain, only the input hashes are stored.
/// @notice See `LibInput` for more details on how such hashes are computed.
interface IInputBox {
    /// @notice MUST trigger when an input is added.
    /// @param appContract The application contract address
    /// @param index The input index
    /// @param input The input blob
    event InputAdded(address indexed appContract, uint256 indexed index, bytes input);

    /// @notice Input is too large.
    /// @param appContract The application contract address
    /// @param inputLength The input length
    /// @param maxInputLength The maximum input length
    error InputTooLarge(address appContract, uint256 inputLength, uint256 maxInputLength);

    /// @notice Send an input to an application.
    /// @param appContract The application contract address
    /// @param payload The input payload
    /// @return The hash of the input blob
    /// @dev MUST fire an `InputAdded` event.
    function addInput(address appContract, bytes calldata payload)
        external
        returns (bytes32);

    /// @notice Get the number of inputs sent to an application.
    /// @param appContract The application contract address
    function getNumberOfInputs(address appContract) external view returns (uint256);

    /// @notice Get the hash of an input in an application's input box.
    /// @param appContract The application contract address
    /// @param index The input index
    /// @dev The provided index must be valid.
    function getInputHash(address appContract, uint256 index)
        external
        view
        returns (bytes32);

    /// @notice Get number of block in which contract was deployed
    function getDeploymentBlockNumber() external view returns (uint256);
}
