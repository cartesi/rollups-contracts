// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {Test} from "forge-std-1.9.6/src/Test.sol";

import {Outputs} from "src/common/Outputs.sol";
import {Voucher} from "src/common/Voucher.sol";
import {LibBytes} from "src/library/LibBytes.sol";
import {LibVoucher} from "src/library/LibVoucher.sol";

contract LibVoucherTest is Test {
    using LibBytes for bytes;
    using LibVoucher for Voucher;

    function testEncode(Voucher calldata voucher) external pure {
        bytes memory output = voucher.encode();
        (bool isValid, bytes4 selector, bytes memory args) = output.consumeBytes4();
        assertTrue(isValid, "Encoded voucher is not valid output");
        assertEq(selector, Outputs.Voucher.selector, "Invalid selector");
        uint256 payloadLength = voucher.payload.length;
        uint256 payloadWordCount = (payloadLength + 31) >> 5;
        assertEq(args.length, (4 + payloadWordCount) * 32, "Invalid arguments length");
        address arg1;
        uint256 arg2;
        bytes memory arg3;
        (arg1, arg2, arg3) = abi.decode(args, (address, uint256, bytes));
        assertEq(arg1, voucher.destination, "Invalid destination");
        assertEq(arg2, voucher.value, "Invalid value");
        assertEq(arg3, voucher.payload, "Invalid payload");
    }
}
