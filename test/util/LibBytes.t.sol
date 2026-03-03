// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Test} from "forge-std-1.9.6/src/Test.sol";

import {LibBytes} from "./LibBytes.sol";

contract LibBytesTest is Test {
    using LibBytes for bytes;

    function testConsumeBytes4(bytes calldata buffer) external pure {
        try buffer.consumeBytes4() returns (bytes4 value, bytes memory suffix) {
            assertEq(buffer, abi.encodePacked(value, suffix));
        } catch (bytes memory error) {
            _testConsumeError(error, buffer, 4);
        }
    }

    function testConsumeAddress(bytes calldata buffer) external pure {
        try buffer.consumeAddress() returns (address value, bytes memory suffix) {
            assertEq(buffer, abi.encodePacked(value, suffix));
        } catch (bytes memory error) {
            _testConsumeError(error, buffer, 20);
        }
    }

    function testConsumeUint256(bytes calldata buffer) external pure {
        try buffer.consumeUint256() returns (uint256 value, bytes memory suffix) {
            assertEq(buffer, abi.encodePacked(value, suffix));
        } catch (bytes memory error) {
            _testConsumeError(error, buffer, 32);
        }
    }

    function _testConsumeError(bytes memory error, bytes memory buffer, uint256 minSize)
        internal
        pure
    {
        assertLt(buffer.length, minSize);
        assertEq(error, _encodeBufferTooSmall(buffer, minSize));
    }

    function _encodeBufferTooSmall(bytes memory buffer, uint256 minSize)
        internal
        pure
        returns (bytes memory encodedError)
    {
        return abi.encodeWithSelector(LibBytes.BufferTooSmall.selector, buffer, minSize);
    }
}
