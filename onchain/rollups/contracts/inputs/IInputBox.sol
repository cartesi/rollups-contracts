// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

/// @title Input Box interface
interface IInputBox {
    /// @notice Raised when input is larger than the machine limit.
    error InputSizeExceedsLimit();

    /// @notice Emitted when an input is added to a DApp's input box.
    /// @param dapp The address of the DApp
    /// @param index The index of the input in the DApp's input box
    /// @param input The input blob
    /// @dev MUST be triggered on a successful call to `addInput`.
    event InputAdded(address indexed dapp, uint256 indexed index, bytes input);

    /// @notice Add an input to a DApp's input box.
    /// @param _dapp The address of the DApp
    /// @param _payload The input payload
    /// @return The hash of the input blob
    /// @dev MUST fire an `InputAdded` event accordingly.
    ///      Input larger than machine limit will raise `InputSizeExceedsLimit` error.
    function addInput(
        address _dapp,
        bytes calldata _payload
    ) external returns (bytes32);

    /// @notice Get the number of inputs in a DApp's input box.
    /// @param _dapp The address of the DApp
    /// @return Number of inputs in the DApp's input box
    function getNumberOfInputs(address _dapp) external view returns (uint256);

    /// @notice Get the hash of an input in a DApp's input box.
    /// @param _dapp The address of the DApp
    /// @param _index The index of the input in the DApp's input box
    /// @return The hash of the input at the provided index in the DApp's input box
    /// @dev `_index` MUST be in the interval `[0,n)` where `n` is the number of
    ///      inputs in the DApp's input box. See the `getNumberOfInputs` function.
    function getInputHash(
        address _dapp,
        uint256 _index
    ) external view returns (bytes32);
}
