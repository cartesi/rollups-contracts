// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {Test} from "forge-std-1.9.6/src/Test.sol";

import {DelegateCallVoucher} from "../../src/common/DelegateCallVoucher.sol";
import {Outputs} from "../../src/common/Outputs.sol";
import {LibBytes} from "../../src/library/LibBytes.sol";
import {LibDelegateCallVoucher} from "../../src/library/LibDelegateCallVoucher.sol";

contract LibDelegateCallVoucherTest is Test {
    using LibBytes for bytes;
    using LibDelegateCallVoucher for DelegateCallVoucher;

    function testEncode(DelegateCallVoucher calldata delegateCallVoucher) external pure {
        bytes memory output = delegateCallVoucher.encode();
        (bool isValid, bytes4 selector, bytes memory args) = output.consumeBytes4();
        assertTrue(isValid, "Encoded delegate-call voucher is not valid output");
        assertEq(selector, Outputs.DelegateCallVoucher.selector, "Invalid selector");
        uint256 payloadLength = delegateCallVoucher.payload.length;
        uint256 payloadWordCount = (payloadLength + 31) >> 5;
        assertEq(args.length, (3 + payloadWordCount) * 32, "Invalid arguments length");
        address arg1;
        bytes memory arg2;
        (arg1, arg2) = abi.decode(args, (address, bytes));
        assertEq(arg1, delegateCallVoucher.destination, "Invalid destination");
        assertEq(arg2, delegateCallVoucher.payload, "Invalid payload");
    }
}
