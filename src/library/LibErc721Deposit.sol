// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {Erc721Deposit} from "../common/Erc721Deposit.sol";
import {Voucher} from "../common/Voucher.sol";

/// @title Auxiliary interface for encoding calls to ERC-721 safeTransferFrom
/// with abi.encodeCall (which leverages Solidity type checker) instead of
/// abi.encodeWithSignature (which does not type-check call arguments).
/// @dev See https://github.com/argotorg/solidity/issues/3556
interface IERC721SafeTransferFromWithoutData {
    function safeTransferFrom(address, address, uint256) external;
}

library LibErc721Deposit {
    function buildRefund(Erc721Deposit memory deposit, address appContract)
        internal
        pure
        returns (Voucher memory voucher)
    {
        return Voucher({
            destination: address(deposit.token),
            value: 0,
            payload: abi.encodeCall(
                IERC721SafeTransferFromWithoutData.safeTransferFrom,
                (appContract, deposit.sender, deposit.tokenId)
            )
        });
    }
}
