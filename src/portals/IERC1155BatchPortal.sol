// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IERC1155} from "@openzeppelin-contracts-5.2.0/token/ERC1155/IERC1155.sol";

import {App} from "../app/interfaces/App.sol";

/// @title ERC-1155 Batch Transfer Portal interface
interface IERC1155BatchPortal {
    // Permissionless functions

    /// @notice Transfer a batch of ERC-1155 tokens of multiple types to an application contract
    /// and add an input to the application's input box to signal such operation.
    ///
    /// The caller must enable approval for the portal to manage all of their tokens
    /// beforehand, by calling the `setApprovalForAll` function in the token contract.
    ///
    /// @param token The ERC-1155 token contract
    /// @param appContract The application contract address
    /// @param tokenIds The identifiers of the tokens being transferred
    /// @param values Transfer amounts per token type
    /// @param baseLayerData Additional data to be interpreted by the base layer
    /// @param execLayerData Additional data to be interpreted by the execution layer
    ///
    /// @dev Please make sure the arrays `tokenIds` and `values` have the same length.
    function depositBatchERC1155Token(
        IERC1155 token,
        App appContract,
        uint256[] calldata tokenIds,
        uint256[] calldata values,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external;
}
