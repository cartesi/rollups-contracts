// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {Test} from "forge-std-1.9.6/src/Test.sol";

import {EtherDeposit} from "../../src/common/EtherDeposit.sol";
import {Voucher} from "../../src/common/Voucher.sol";
import {LibEtherDeposit} from "../../src/library/LibEtherDeposit.sol";

contract LibEtherDepositTest is Test {
    using LibEtherDeposit for EtherDeposit;

    function testBuildRefund(EtherDeposit calldata deposit) external pure {
        Voucher memory voucher = deposit.buildRefund();
        assertEq(voucher.destination, deposit.sender, "destination");
        assertEq(voucher.value, deposit.value, "value");
        assertEq(voucher.payload.length, 0, "payload length");
    }
}
