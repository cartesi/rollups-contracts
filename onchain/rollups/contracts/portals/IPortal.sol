// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IInputBox} from "../inputs/IInputBox.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @title Portal interface
interface IPortal is IERC165 {
    // Permissionless functions

    /// @notice Get the input box used by this portal.
    /// @return The input box
    function getInputBox() external view returns (IInputBox);
}
