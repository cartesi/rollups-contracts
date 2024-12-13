// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IInputBox} from "../inputs/IInputBox.sol";

/// @title Data Availability
/// @notice Defines the signatures of data availability solutions.
interface DataAvailability {
    /// @notice The application receives inputs only from
    /// a contract that implements the `IInputBox` interface.
    /// @param inputBox The input box contract address
    function InputBox(IInputBox inputBox) external;

    /// @notice The application receives inputs from
    /// a contract that implements the `IInputBox` interface,
    /// and from Espresso, starting from a given block height,
    /// and for a given namespace ID.
    /// @param inputBox The input box contract address
    /// @param fromBlock Height of first Espresso block to consider
    /// @param namespaceId The Espresso namespace ID
    function InputBoxAndEspresso(
        IInputBox inputBox,
        uint256 fromBlock,
        uint32 namespaceId
    ) external;
}
