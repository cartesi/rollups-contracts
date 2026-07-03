// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {IERC1155Receiver} from "@openzeppelin-contracts-5.2.0/token/ERC1155/IERC1155Receiver.sol";
import {IERC721Receiver} from "@openzeppelin-contracts-5.2.0/token/ERC721/IERC721Receiver.sol";
import {ERC165} from "@openzeppelin-contracts-5.2.0/utils/introspection/ERC165.sol";
import {IERC165} from "@openzeppelin-contracts-5.2.0/utils/introspection/IERC165.sol";

contract AssetReceiver is ERC165, IERC721Receiver, IERC1155Receiver {
    /// @notice Raised on Ether transfers
    error EtherRejected(address sender, uint256 value);

    /// @notice Raised on ERC-721 transfers
    error Erc721Rejected(
        address token, address operator, address from, uint256 tokenId, bytes data
    );

    /// @notice Raised on ERC-1155 transfers
    error Erc1155Rejected(
        address token,
        address operator,
        address from,
        uint256 tokenId,
        uint256 value,
        bytes data
    );

    /// @notice Raised on ERC-1155 batch transfers
    error Erc1155BatchRejected(
        address token,
        address operator,
        address from,
        uint256[] tokenIds,
        uint256[] values,
        bytes data
    );

    bool private _rejecting;

    function isRejecting() external view returns (bool) {
        return _rejecting;
    }

    function setRejecting(bool rejecting) external {
        _rejecting = rejecting;
    }

    receive() external payable {
        if (_rejecting) {
            revert EtherRejected(msg.sender, msg.value);
        }
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external view override returns (bytes4) {
        if (_rejecting) {
            revert Erc721Rejected(msg.sender, operator, from, tokenId, data);
        } else {
            return IERC721Receiver.onERC721Received.selector;
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165, IERC165)
        returns (bool)
    {
        return interfaceId == type(IERC1155Receiver).interfaceId
            || super.supportsInterface(interfaceId);
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 tokenId,
        uint256 value,
        bytes calldata data
    ) external view override returns (bytes4) {
        if (_rejecting) {
            revert Erc1155Rejected(msg.sender, operator, from, tokenId, value, data);
        } else {
            return IERC1155Receiver.onERC1155Received.selector;
        }
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata tokenIds,
        uint256[] calldata values,
        bytes calldata data
    ) external view override returns (bytes4) {
        if (_rejecting) {
            revert Erc1155BatchRejected(
                msg.sender, operator, from, tokenIds, values, data
            );
        } else {
            return IERC1155Receiver.onERC1155BatchReceived.selector;
        }
    }
}
