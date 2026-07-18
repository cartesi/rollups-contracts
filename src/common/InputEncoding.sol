// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {IERC1155} from "@openzeppelin-contracts-5.2.0/token/ERC1155/IERC1155.sol";
import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin-contracts-5.2.0/token/ERC721/IERC721.sol";

import {Erc1155BatchDeposit} from "./Erc1155BatchDeposit.sol";
import {Erc1155SingleDeposit} from "./Erc1155SingleDeposit.sol";
import {Erc20Deposit} from "./Erc20Deposit.sol";
import {Erc721Deposit} from "./Erc721Deposit.sol";
import {EtherDeposit} from "./EtherDeposit.sol";

/// @title Input Encoding Library

/// @notice Defines the encoding of inputs added by core trustless and
/// permissionless contracts, such as portals.
library InputEncoding {
    /// @notice Encode an Ether deposit.
    /// @param sender The Ether sender
    /// @param value The amount of Wei being sent
    /// @param execLayerData Additional data to be interpreted by the execution layer
    /// @return The encoded input payload
    function encodeEtherDeposit(
        address sender,
        uint256 value,
        bytes calldata execLayerData
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(
            sender, //              20B
            value, //               32B
            execLayerData //        arbitrary size
        );
    }

    /// @notice Decode an Ether deposit.
    /// @param payload The encoded input payload
    /// @return deposit The decoded Ether deposit
    function decodeEtherDeposit(bytes calldata payload)
        internal
        pure
        returns (EtherDeposit memory deposit)
    {
        return EtherDeposit({
            sender: address(uint160(bytes20(payload[:20]))),
            value: uint256(bytes32(payload[20:52]))
        });
    }

    /// @notice Encode an ERC-20 token deposit.
    /// @param token The token contract
    /// @param sender The token sender
    /// @param value The amount of tokens being sent
    /// @param execLayerData Additional data to be interpreted by the execution layer
    /// @return The encoded input payload
    function encodeErc20Deposit(
        IERC20 token,
        address sender,
        uint256 value,
        bytes calldata execLayerData
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(
            token, //               20B
            sender, //              20B
            value, //               32B
            execLayerData //        arbitrary size
        );
    }

    /// @notice Decode an ERC-20 token deposit.
    /// @param payload The encoded input payload
    /// @return deposit The decoded ERC-20 token deposit
    function decodeErc20Deposit(bytes calldata payload)
        internal
        pure
        returns (Erc20Deposit memory deposit)
    {
        return Erc20Deposit({
            token: IERC20(address(uint160(bytes20(payload[:20])))),
            sender: address(uint160(bytes20(payload[20:40]))),
            value: uint256(bytes32(payload[40:72]))
        });
    }

    /// @notice Encode an ERC-721 token deposit.
    /// @param token The token contract
    /// @param sender The token sender
    /// @param tokenId The token identifier
    /// @param baseLayerData Additional data to be interpreted by the base layer
    /// @param execLayerData Additional data to be interpreted by the execution layer
    /// @return The encoded input payload
    /// @dev `baseLayerData` should be forwarded to `token`.
    function encodeErc721Deposit(
        IERC721 token,
        address sender,
        uint256 tokenId,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) internal pure returns (bytes memory) {
        bytes memory data = abi.encode(baseLayerData, execLayerData);
        return abi.encodePacked(
            token, //               20B
            sender, //              20B
            tokenId, //             32B
            data //                 arbitrary size
        );
    }

    /// @notice Decode an ERC-721 token deposit.
    /// @param payload The encoded input payload
    /// @return deposit The decoded ERC-721 token deposit
    function decodeErc721Deposit(bytes calldata payload)
        internal
        pure
        returns (Erc721Deposit memory deposit)
    {
        return Erc721Deposit({
            token: IERC721(address(uint160(bytes20(payload[:20])))),
            sender: address(uint160(bytes20(payload[20:40]))),
            tokenId: uint256(bytes32(payload[40:72]))
        });
    }

    /// @notice Encode an ERC-1155 single token deposit.
    /// @param token The ERC-1155 token contract
    /// @param sender The token sender
    /// @param tokenId The identifier of the token being transferred
    /// @param value Transfer amount
    /// @param baseLayerData Additional data to be interpreted by the base layer
    /// @param execLayerData Additional data to be interpreted by the execution layer
    /// @return The encoded input payload
    /// @dev `baseLayerData` should be forwarded to `token`.
    function encodeSingleErc1155Deposit(
        IERC1155 token,
        address sender,
        uint256 tokenId,
        uint256 value,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) internal pure returns (bytes memory) {
        bytes memory data = abi.encode(baseLayerData, execLayerData);
        return abi.encodePacked(
            token, //               20B
            sender, //              20B
            tokenId, //             32B
            value, //               32B
            data //                 arbitrary size
        );
    }

    /// @notice Decode an ERC-1155 single token deposit.
    /// @param payload The encoded input payload
    /// @return deposit The decoded ERC-1155 single token deposit
    function decodeErc1155SingleDeposit(bytes calldata payload)
        internal
        pure
        returns (Erc1155SingleDeposit memory deposit)
    {
        return Erc1155SingleDeposit({
            token: IERC1155(address(uint160(bytes20(payload[:20])))),
            sender: address(uint160(bytes20(payload[20:40]))),
            tokenId: uint256(bytes32(payload[40:72])),
            value: uint256(bytes32(payload[72:104]))
        });
    }

    /// @notice Encode an ERC-1155 batch token deposit.
    /// @param token The ERC-1155 token contract
    /// @param sender The token sender
    /// @param tokenIds The identifiers of the tokens being transferred
    /// @param values Transfer amounts per token type
    /// @param baseLayerData Additional data to be interpreted by the base layer
    /// @param execLayerData Additional data to be interpreted by the execution layer
    /// @return The encoded input payload
    /// @dev `baseLayerData` should be forwarded to `token`.
    function encodeBatchErc1155Deposit(
        IERC1155 token,
        address sender,
        uint256[] calldata tokenIds,
        uint256[] calldata values,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) internal pure returns (bytes memory) {
        bytes memory data = abi.encode(tokenIds, values, baseLayerData, execLayerData);
        return abi.encodePacked(
            token, //                   20B
            sender, //                  20B
            data //                     arbitrary size
        );
    }

    /// @notice Decode an ERC-1155 batch token deposit.
    /// @param payload The encoded input payload
    /// @return deposit The decoded ERC-1155 batch token deposit
    function decodeErc1155BatchDeposit(bytes calldata payload)
        internal
        pure
        returns (Erc1155BatchDeposit memory deposit)
    {
        bytes calldata data = payload[40:];
        uint256[] memory tokenIds;
        uint256[] memory values;
        (tokenIds, values,,) = abi.decode(data, (uint256[], uint256[], bytes, bytes));
        return Erc1155BatchDeposit({
            token: IERC1155(address(uint160(bytes20(payload[:20])))),
            sender: address(uint160(bytes20(payload[20:40]))),
            tokenIds: tokenIds,
            values: values
        });
    }
}
