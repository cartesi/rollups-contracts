// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

/// @title Input Box interface
interface IInputBox {
    /// @notice Emitted when an input is added to an application's input box.
    /// @param app The address of the application
    /// @param inputIndex The index of the input in the input box
    /// @param sender The address that sent the input
    /// @param input The contents of the input
    /// @dev MUST be triggered on a successful call to `addInput`.
    event InputAdded(
        address indexed app,
        uint256 indexed inputIndex,
        address sender,
        bytes input
    );

    /// @notice Add an input to an application's input box.
    /// @param _app The address of the application
    /// @param _input The contents of the input
    /// @return The hash of the input plus some extra metadata
    /// @dev MUST fire an `InputAdded` event accordingly.
    ///      Input larger than machine limit will raise `InputSizeExceedsLimit` error.
    function addInput(
        address _app,
        bytes calldata _input
    ) external returns (bytes32);

    /// @notice Get the number of inputs in an application's input box.
    /// @param _app The address of the application
    /// @return Number of inputs in the application's input box
    function getNumberOfInputs(address _app) external view returns (uint256);

    /// @notice Get the hash of an input in an application's input box.
    /// @param _app The address of the application
    /// @param _index The index of the input in the application's input box
    /// @return The hash of the input at the provided index in the application's input box
    /// @dev `_index` MUST be in the interval `[0,n)` where `n` is the number of
    ///      inputs in the application's input box. See the `getNumberOfInputs` function.
    function getInputHash(
        address _app,
        uint256 _index
    ) external view returns (bytes32);
}
