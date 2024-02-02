// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IPortal} from "./IPortal.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/// @title ERC-1155 Batch Transfer Portal interface
interface IERC1155BatchPortal is IPortal {
    // Permissionless functions

    /// @notice Transfer a batch of ERC-1155 tokens to an application and add an input to
    /// the application's input box to signal such operation.
    ///
    /// The caller must enable approval for the portal to manage all of their tokens
    /// beforehand, by calling the `setApprovalForAll` function in the token contract.
    ///
    /// @param token The ERC-1155 token contract
    /// @param app The address of the application
    /// @param tokenIds The identifiers of the tokens being transferred
    /// @param values Transfer amounts per token type
    /// @param baseLayerData Additional data to be interpreted by the base layer
    /// @param execLayerData Additional data to be interpreted by the execution layer
    ///
    /// @dev Please make sure `tokenIds` and `values` have the same length.
    function depositBatchERC1155Token(
        IERC1155 token,
        address app,
        uint256[] calldata tokenIds,
        uint256[] calldata values,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external;
}
