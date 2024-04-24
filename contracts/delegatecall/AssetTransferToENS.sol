// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.20;

import {ENS} from "@ensdomains/ens-contracts/contracts/registry/ENS.sol";
import {AddrResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/AddrResolver.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import {LibAddress} from "../library/LibAddress.sol";

contract AssetTransferToENS {
    using LibAddress for address;
    using SafeERC20 for IERC20;

    ENS immutable _ens;

    constructor(ENS ens) {
        _ens = ens;
    }

    function sendEtherToENS(
        bytes32 node,
        uint256 value,
        bytes memory payload
    ) external {
        address recipient = _resolveENS(node);
        recipient.safeCall(value, payload);
    }

    function sendERC20ToENS(
        IERC20 token,
        bytes32 node,
        uint256 value
    ) external {
        address recipient = _resolveENS(node);
        token.safeTransfer(recipient, value);
    }

    function sendERC721ToENS(
        IERC721 token,
        bytes32 node,
        uint256 tokenId,
        bytes calldata data
    ) external {
        address recipient = _resolveENS(node);
        token.safeTransferFrom(address(this), recipient, tokenId, data);
    }

    function sendERC1155ToENS(
        IERC1155 token,
        bytes32 node,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external {
        address recipient = _resolveENS(node);
        token.safeTransferFrom(address(this), recipient, id, value, data);
    }

    function sendBatchERC1155ToENS(
        IERC1155 token,
        bytes32 node,
        uint256[] memory ids,
        uint256[] memory values,
        bytes calldata data
    ) external {
        address recipient = _resolveENS(node);
        token.safeBatchTransferFrom(
            address(this),
            recipient,
            ids,
            values,
            data
        );
    }

    function _resolveENS(bytes32 node) internal view returns (address) {
        AddrResolver resolver = AddrResolver(_ens.resolver(node));
        return resolver.addr(node);
    }
}
