// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {Test} from "forge-std-1.9.6/src/Test.sol";

import {IERC1155} from "@openzeppelin-contracts-5.2.0/token/ERC1155/IERC1155.sol";

import {Erc1155SingleDeposit} from "src/common/Erc1155SingleDeposit.sol";
import {Voucher} from "src/common/Voucher.sol";
import {LibBytes} from "src/library/LibBytes.sol";
import {LibErc1155SingleDeposit} from "src/library/LibErc1155SingleDeposit.sol";

contract LibErc1155SingleDepositTest is Test {
    using LibErc1155SingleDeposit for Erc1155SingleDeposit;
    using LibBytes for bytes;

    function testBuildRefund(Erc1155SingleDeposit calldata deposit, address appContract)
        external
        pure
    {
        Voucher memory voucher = deposit.buildRefund(appContract);
        assertEq(voucher.destination, address(deposit.token), "destination");
        assertEq(voucher.value, 0, "voucher value");
        bool isPayloadValid;
        bytes4 selector;
        bytes memory args;
        (isPayloadValid, selector, args) = voucher.payload.consumeBytes4();
        assertTrue(isPayloadValid, "is payload valid");
        assertEq(selector, IERC1155.safeTransferFrom.selector);
        address arg1;
        address arg2;
        uint256 arg3;
        uint256 arg4;
        bytes memory arg5;
        (arg1, arg2, arg3, arg4, arg5) =
            abi.decode(args, (address, address, uint256, uint256, bytes));
        assertEq(arg1, appContract, "from");
        assertEq(arg2, deposit.sender, "to");
        assertEq(arg3, deposit.tokenId, "tokenId");
        assertEq(arg4, deposit.value, "transfer value");
        assertEq(arg5, new bytes(0), "transfer extra data");
    }
}
