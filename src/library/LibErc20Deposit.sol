// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {DelegateCallVoucher} from "../common/DelegateCallVoucher.sol";
import {Erc20Deposit} from "../common/Erc20Deposit.sol";
import {ISafeERC20Transfer} from "../delegatecall/ISafeERC20Transfer.sol";

library LibErc20Deposit {
    function buildRefund(Erc20Deposit memory deposit, ISafeERC20Transfer safeTransfer)
        internal
        pure
        returns (DelegateCallVoucher memory delegateCallVoucher)
    {
        return DelegateCallVoucher({
            destination: address(safeTransfer),
            payload: abi.encodeCall(
                ISafeERC20Transfer.safeTransfer,
                (deposit.token, deposit.sender, deposit.value)
            )
        });
    }
}
