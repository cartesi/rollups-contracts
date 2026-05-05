// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {Erc1155SingleDeposit} from "../common/Erc1155SingleDeposit.sol";
import {Voucher} from "../common/Voucher.sol";

library LibErc1155SingleDeposit {
    function buildRefund(Erc1155SingleDeposit memory deposit, address appContract)
        internal
        pure
        returns (Voucher memory voucher)
    {
        return Voucher({
            destination: address(deposit.token),
            value: 0,
            payload: abi.encodeCall(
                deposit.token.safeTransferFrom,
                (
                    appContract,
                    deposit.sender,
                    deposit.tokenId,
                    deposit.value,
                    new bytes(0) // no ERC-1155 transfer data
                )
            )
        });
    }
}
