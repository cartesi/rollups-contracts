// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {EtherDeposit} from "../common/EtherDeposit.sol";
import {Voucher} from "../common/Voucher.sol";

library LibEtherDeposit {
    function buildRefund(EtherDeposit memory deposit)
        internal
        pure
        returns (Voucher memory voucher)
    {
        return Voucher({
            destination: deposit.sender,
            value: deposit.value,
            payload: new bytes(0) // triggers receive() on Solidity (>= 0.6.0) contracts
        });
    }
}
