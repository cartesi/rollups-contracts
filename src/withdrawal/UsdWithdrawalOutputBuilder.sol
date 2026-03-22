// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";

import {Outputs} from "../common/Outputs.sol";
import {RollupsContract} from "../common/RollupsContract.sol";
import {ISafeERC20Transfer} from "../delegatecall/ISafeERC20Transfer.sol";
import {LibUsdAccount} from "../library/LibUsdAccount.sol";
import {IUsdWithdrawalOutputBuilder} from "./IUsdWithdrawalOutputBuilder.sol";

contract UsdWithdrawalOutputBuilder is IUsdWithdrawalOutputBuilder, RollupsContract {
    ISafeERC20Transfer immutable SAFE_ERC20_TRANSFER;
    IERC20 immutable USD;

    constructor(ISafeERC20Transfer safeTransfer, IERC20 usd) {
        SAFE_ERC20_TRANSFER = safeTransfer;
        USD = usd;
    }

    function token() external view override returns (IERC20) {
        return USD;
    }

    function buildWithdrawalOutput(bytes calldata account)
        external
        view
        override
        returns (bytes memory output)
    {
        (address user, uint256 balance) = LibUsdAccount.decode(account);
        address destination = address(SAFE_ERC20_TRANSFER);
        bytes memory payload = _encodeSafeTransferPayload(user, balance);
        return _encodeDelegateCallVoucher(destination, payload);
    }

    function _encodeSafeTransferPayload(address user, uint256 value)
        internal
        view
        returns (bytes memory payload)
    {
        return abi.encodeCall(ISafeERC20Transfer.safeTransfer, (USD, user, value));
    }

    function _encodeDelegateCallVoucher(address destination, bytes memory payload)
        internal
        pure
        returns (bytes memory output)
    {
        return abi.encodeCall(Outputs.DelegateCallVoucher, (destination, payload));
    }
}
