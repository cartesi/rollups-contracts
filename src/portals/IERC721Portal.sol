// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IERC721} from "@openzeppelin-contracts-5.2.0/token/ERC721/IERC721.sol";

import {IApp} from "../app/interfaces/IApp.sol";
import {IPortal} from "./IPortal.sol";

/// @title ERC-721 Portal interface
interface IERC721Portal is IPortal {
    // Permissionless functions

    /// @notice Transfer an ERC-721 token to an application contract
    /// and add an input to the application's input box to signal such operation.
    ///
    /// The caller must change the approved address for the ERC-721 token
    /// to the portal address beforehand, by calling the `approve` function in the
    /// token contract.
    ///
    /// @param token The ERC-721 token contract
    /// @param appContract The application contract address
    /// @param tokenId The identifier of the token being transferred
    /// @param baseLayerData Additional data to be interpreted by the base layer
    /// @param execLayerData Additional data to be interpreted by the execution layer
    function depositERC721Token(
        IERC721 token,
        IApp appContract,
        uint256 tokenId,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external;
}
