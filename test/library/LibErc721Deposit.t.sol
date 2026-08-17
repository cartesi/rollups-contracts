// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {Test} from "forge-std-1.9.6/src/Test.sol";

import {Erc721Deposit} from "../../src/common/Erc721Deposit.sol";
import {Voucher} from "../../src/common/Voucher.sol";
import {LibBytes} from "../../src/library/LibBytes.sol";
import {LibErc721Deposit} from "../../src/library/LibErc721Deposit.sol";

contract LibErc721DepositTest is Test {
    using LibErc721Deposit for Erc721Deposit;
    using LibBytes for bytes;

    function testBuildRefund(Erc721Deposit calldata deposit, address appContract)
        external
        pure
    {
        Voucher memory voucher = deposit.buildRefund(appContract);
        assertEq(voucher.destination, address(deposit.token), "destination");
        assertEq(voucher.value, 0, "value");
        bool isPayloadValid;
        bytes4 selector;
        bytes memory args;
        (isPayloadValid, selector, args) = voucher.payload.consumeBytes4();
        assertTrue(isPayloadValid, "is payload valid");
        assertEq(selector, bytes4(keccak256("safeTransferFrom(address,address,uint256)")));
        address arg1;
        address arg2;
        uint256 arg3;
        (arg1, arg2, arg3) = abi.decode(args, (address, address, uint256));
        assertEq(arg1, appContract, "from");
        assertEq(arg2, deposit.sender, "to");
        assertEq(arg3, deposit.tokenId, "tokenId");
    }
}
