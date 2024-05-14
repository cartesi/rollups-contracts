// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {ENS} from "@ensdomains/ens-contracts/contracts/registry/ENS.sol";

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IENSPortal} from "./IENSPortal.sol";
import {Portal} from "./Portal.sol";
import {IInputBox} from "../inputs/IInputBox.sol";
import {InputEncoding} from "../common/InputEncoding.sol";
import {LibENS} from "../library/LibENS.sol";

/// @title ENS Portal
///
/// @notice This contract allows anyone to send input to the InputBox with ENS
contract ENSPortal is IENSPortal, Portal {
    using LibENS for ENS;

    ENS immutable _ens;

    /// @notice Constructs the portal.
    /// @param inputBox The input box used by the portal
    /// @param ens The ENS registry
    constructor(IInputBox inputBox, ENS ens) Portal(inputBox) {
        _ens = ens;
    }

    function sendInputWithENS(
        address appContract,
        bytes32 node,
        bytes calldata name,
        bytes calldata execLayerData
    ) external override {
        address resolution = _ens.resolveToAddress(node);

        if (resolution != msg.sender) {
            revert AddressResolutionMismatch(resolution, msg.sender);
        }

        bytes memory payload = InputEncoding.encodeENSInput(
            node,
            name,
            execLayerData
        );

        _inputBox.addInput(appContract, payload);
    }

    function getENS() external view override returns (ENS) {
        return _ens;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165, Portal) returns (bool) {
        return
            interfaceId == type(IENSPortal).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
