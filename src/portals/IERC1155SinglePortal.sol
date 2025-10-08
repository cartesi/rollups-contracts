// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IERC1155} from "@openzeppelin-contracts-5.2.0/token/ERC1155/IERC1155.sol";

import {App} from "../app/interfaces/App.sol";

/// @title ERC-1155 Single Transfer Portal interface
interface IERC1155SinglePortal {
    // Permissionless functions

    /// @notice Transfer ERC-1155 tokens of a single type to an application contract
    /// and add an input to the application's input box to signal such operation.
    ///
    /// The caller must enable approval for the portal to manage all of their tokens
    /// beforehand, by calling the `setApprovalForAll` function in the token contract.
    ///
    /// @param token The ERC-1155 token contract
    /// @param appContract The application contract address
    /// @param tokenId The identifier of the token being transferred
    /// @param value Transfer amount
    /// @param baseLayerData Additional data to be interpreted by the base layer
    /// @param execLayerData Additional data to be interpreted by the execution layer
    function depositSingleERC1155Token(
        IERC1155 token,
        App appContract,
        uint256 tokenId,
        uint256 value,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external;
}
