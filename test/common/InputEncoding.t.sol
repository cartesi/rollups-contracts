// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin-contracts-5.2.0/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin-contracts-5.2.0/token/ERC1155/IERC1155.sol";

import {Test} from "forge-std-1.10.0/src/Test.sol";

import {InputEncoding} from "src/common/InputEncoding.sol";

library LibPackedEncoding {
    /// @notice This error is raised when an invalid byte index is used
    /// to retrieve the byte of a byte array.
    /// @param index The byte index
    /// @param byteArrayLength The byte array length
    error InvalidByteIndex(uint256 index, uint256 byteArrayLength);

    /// @notice Split a byte array in a given index.
    /// @param b The byte array
    /// @param index The index in the byte array
    /// @return beforeIndex The byte array before the index (exclusive)
    /// @return afterIndex The byte array after the index (inclusive)
    function splitAt(bytes memory b, uint256 index)
        external
        pure
        returns (bytes memory beforeIndex, bytes memory afterIndex)
    {
        require(index <= b.length, InvalidByteIndex(index, b.length));

        // Copy the data before the index.
        beforeIndex = new bytes(index);
        for (uint256 i; i < beforeIndex.length; ++i) {
            beforeIndex[i] = b[i];
        }

        // Copy the data after the index.
        afterIndex = new bytes(b.length - index);
        for (uint256 i; i < afterIndex.length; ++i) {
            afterIndex[i] = b[beforeIndex.length + i];
        }
    }
}

contract LibPackedEncodingTest is Test {
    using LibPackedEncoding for bytes;

    function testSplitAt(bytes[2] memory parts) external pure {
        bytes memory b = abi.encodePacked(parts[0], parts[1]);
        (bytes memory bLeft, bytes memory bRight) = b.splitAt(parts[0].length);
        assertEq(bLeft, parts[0]);
        assertEq(bRight, parts[1]);
    }

    function testSplitAtError(bytes memory b) external {
        uint256 index = vm.randomUint(b.length + 1, type(uint256).max);
        vm.expectRevert(_encodeInvalidByteIndex(index, b.length));
        b.splitAt(index);
    }

    /// @notice Encode an `InvalidByteIndex` error.
    /// @param index The byte index
    /// @param byteArrayLength The byte array length
    /// @return The encoded error
    function _encodeInvalidByteIndex(uint256 index, uint256 byteArrayLength)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            LibPackedEncoding.InvalidByteIndex.selector, index, byteArrayLength
        );
    }
}

contract InputEncodingTest is Test {
    using LibPackedEncoding for bytes;

    function testEncodeEtherDeposit(
        address sender,
        uint256 value,
        bytes calldata execLayerData
    ) external pure {
        bytes memory buffer;
        bytes memory field;

        buffer = InputEncoding.encodeEtherDeposit(sender, value, execLayerData);

        (field, buffer) = buffer.splitAt(20);

        assertEq(address(uint160(bytes20(field))), sender);

        (field, buffer) = buffer.splitAt(32);

        assertEq(uint256(bytes32(field)), value);
        assertEq(buffer, execLayerData);
    }

    function testEncodeERC20Deposit(
        IERC20 token,
        address sender,
        uint256 value,
        bytes calldata execLayerData
    ) external pure {
        bytes memory buffer;
        bytes memory field;

        buffer = InputEncoding.encodeERC20Deposit(token, sender, value, execLayerData);

        (field, buffer) = buffer.splitAt(20);

        assertEq(address(uint160(bytes20(field))), address(token));

        (field, buffer) = buffer.splitAt(20);

        assertEq(address(uint160(bytes20(field))), sender);

        (field, buffer) = buffer.splitAt(32);

        assertEq(uint256(bytes32(field)), value);
        assertEq(buffer, execLayerData);
    }

    function testEncodeERC721Deposit(
        IERC721 token,
        address sender,
        uint256 tokenId,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external pure {
        bytes memory buffer;
        bytes memory field;

        buffer = InputEncoding.encodeERC721Deposit(
            token, sender, tokenId, baseLayerData, execLayerData
        );

        (field, buffer) = buffer.splitAt(20);

        assertEq(address(uint160(bytes20(field))), address(token));

        (field, buffer) = buffer.splitAt(20);

        assertEq(address(uint160(bytes20(field))), sender);

        (field, buffer) = buffer.splitAt(32);

        assertEq(uint256(bytes32(field)), tokenId);

        (bytes memory a, bytes memory b) = abi.decode(buffer, (bytes, bytes));

        assertEq(a, baseLayerData);
        assertEq(b, execLayerData);
    }

    function testEncodeSingleERC1155Deposit(
        IERC1155 token,
        address sender,
        uint256 tokenId,
        uint256 value,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external pure {
        bytes memory buffer;
        bytes memory field;

        buffer = InputEncoding.encodeSingleERC1155Deposit(
            token, sender, tokenId, value, baseLayerData, execLayerData
        );

        (field, buffer) = buffer.splitAt(20);

        assertEq(address(uint160(bytes20(field))), address(token));

        (field, buffer) = buffer.splitAt(20);

        assertEq(address(uint160(bytes20(field))), sender);

        (field, buffer) = buffer.splitAt(32);

        assertEq(uint256(bytes32(field)), tokenId);

        (field, buffer) = buffer.splitAt(32);

        assertEq(uint256(bytes32(field)), value);

        (bytes memory a, bytes memory b) = abi.decode(buffer, (bytes, bytes));

        assertEq(a, baseLayerData);
        assertEq(b, execLayerData);
    }

    function testEncodeBatchERC1155Deposit(
        IERC1155 token,
        address sender,
        uint256[] calldata tokenIds,
        uint256[] calldata values,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external pure {
        bytes memory buffer;
        bytes memory field;

        buffer = InputEncoding.encodeBatchERC1155Deposit(
            token, sender, tokenIds, values, baseLayerData, execLayerData
        );

        (field, buffer) = buffer.splitAt(20);

        assertEq(address(uint160(bytes20(field))), address(token));

        (field, buffer) = buffer.splitAt(20);

        assertEq(address(uint160(bytes20(field))), sender);

        (uint256[] memory a, uint256[] memory b, bytes memory c, bytes memory d) =
            abi.decode(buffer, (uint256[], uint256[], bytes, bytes));

        assertEq(a, tokenIds);
        assertEq(b, values);
        assertEq(c, baseLayerData);
        assertEq(d, execLayerData);
    }
}
