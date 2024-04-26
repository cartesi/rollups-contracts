// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IPortal} from "./IPortal.sol";
import {ENS} from "@ensdomains/ens-contracts/contracts/registry/ENS.sol";

/// @title ENS Portal interface
interface IENSPortal is IPortal {
    // Errors

    /// @notice The provided ENS node does not resolve to the sender address.
    /// @param resolution The address that the ENS node resolves to
    /// @param sender The sender address
    error AddressResolutionMismatch(address resolution, address sender);

    // Permissionless functions

    /// @notice Send input to InputBox with ENS.
    /// @param appContract The application contract address
    /// @param node The ENS node
    /// @param name The ENS name
    /// @param execLayerData Additional data to be interpreted by
    /// the execution layer. The data may include the ENS name
    function sendInputWithENS(
        address appContract,
        bytes32 node,
        bytes calldata name,
        bytes calldata execLayerData
    ) external;

    /// @notice Get the ENS registry used by this portal.
    /// @return The ENS registry
    function getENS() external view returns (ENS);
}
