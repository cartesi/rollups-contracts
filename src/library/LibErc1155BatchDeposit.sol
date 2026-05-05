// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {Erc1155BatchDeposit} from "../common/Erc1155BatchDeposit.sol";
import {Voucher} from "../common/Voucher.sol";

library LibErc1155BatchDeposit {
    function buildRefund(Erc1155BatchDeposit memory deposit, address appContract)
        internal
        pure
        returns (Voucher memory voucher)
    {
        return Voucher({
            destination: address(deposit.token),
            value: 0,
            payload: abi.encodeCall(
                deposit.token.safeBatchTransferFrom,
                (
                    appContract,
                    deposit.sender,
                    deposit.tokenIds,
                    deposit.values,
                    new bytes(0) // no ERC-1155 transfer data
                )
            )
        });
    }
}
