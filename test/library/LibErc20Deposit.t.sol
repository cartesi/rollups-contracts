// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {Test} from "forge-std-1.9.6/src/Test.sol";

import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";

import {DelegateCallVoucher} from "src/common/DelegateCallVoucher.sol";
import {Erc20Deposit} from "src/common/Erc20Deposit.sol";
import {ISafeErc20Transfer} from "src/delegatecall/ISafeErc20Transfer.sol";
import {LibBytes} from "src/library/LibBytes.sol";
import {LibErc20Deposit} from "src/library/LibErc20Deposit.sol";

contract LibErc20DepositTest is Test {
    using LibErc20Deposit for Erc20Deposit;
    using LibBytes for bytes;

    function testBuildRefund(
        Erc20Deposit calldata deposit,
        ISafeErc20Transfer safeTransfer
    ) external pure {
        DelegateCallVoucher memory dcVoucher = deposit.buildRefund(safeTransfer);
        assertEq(dcVoucher.destination, address(safeTransfer), "destination");
        bool isPayloadValid;
        bytes4 selector;
        bytes memory args;
        (isPayloadValid, selector, args) = dcVoucher.payload.consumeBytes4();
        assertTrue(isPayloadValid, "is payload valid");
        assertEq(selector, ISafeErc20Transfer.safeTransfer.selector, "selector");
        IERC20 arg1;
        address arg2;
        uint256 arg3;
        (arg1, arg2, arg3) = abi.decode(args, (IERC20, address, uint256));
        assertEq(address(arg1), address(deposit.token), "token");
        assertEq(arg2, deposit.sender, "sender");
        assertEq(arg3, deposit.value, "value");
    }
}
