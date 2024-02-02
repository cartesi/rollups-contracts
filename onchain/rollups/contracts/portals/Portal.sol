// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IPortal} from "./IPortal.sol";
import {IInputBox} from "../inputs/IInputBox.sol";
import {ERC165, IERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/// @title Portal
/// @notice This contract serves as a base for all the other portals.
contract Portal is IPortal, ERC165 {
    /// @notice The input box used by the portal.
    IInputBox internal immutable _inputBox;

    /// @notice Constructs the portal.
    /// @param inputBox The input box used by the portal
    constructor(IInputBox inputBox) {
        _inputBox = inputBox;
    }

    function getInputBox() external view override returns (IInputBox) {
        return _inputBox;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IPortal).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
