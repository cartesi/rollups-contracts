// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";
import {Create2} from "@openzeppelin-contracts-5.2.0/utils/Create2.sol";

import {RollupsContract} from "../common/RollupsContract.sol";
import {ISafeERC20Transfer} from "../delegatecall/ISafeERC20Transfer.sol";
import {IUsdWithdrawalOutputBuilder} from "./IUsdWithdrawalOutputBuilder.sol";
import {
    IUsdWithdrawalOutputBuilderFactory
} from "./IUsdWithdrawalOutputBuilderFactory.sol";
import {UsdWithdrawalOutputBuilder} from "./UsdWithdrawalOutputBuilder.sol";

/// @title USD Withdrawal Output Builder Factory
/// @notice Allows anyone to reliably deploy a new `IUsdWithdrawalOutputBuilder` contract.
contract UsdWithdrawalOutputBuilderFactory is
    IUsdWithdrawalOutputBuilderFactory,
    RollupsContract
{
    ISafeERC20Transfer immutable SAFE_ERC20_TRANSFER;

    constructor(ISafeERC20Transfer safeErc20Transfer) {
        SAFE_ERC20_TRANSFER = safeErc20Transfer;
    }

    function newUsdWithdrawalOutputBuilder(IERC20 token, bytes32 salt)
        external
        override
        returns (IUsdWithdrawalOutputBuilder usdWithdrawalOutputBuilder)
    {
        usdWithdrawalOutputBuilder = new UsdWithdrawalOutputBuilder{salt: salt}(
            SAFE_ERC20_TRANSFER, token
        );

        emit UsdWithdrawalOutputBuilderCreated(usdWithdrawalOutputBuilder);
    }

    function calculateUsdWithdrawalOutputBuilderAddress(IERC20 token, bytes32 salt)
        external
        view
        override
        returns (address usdWithdrawalOutputBuilderAddress)
    {
        return Create2.computeAddress(
            salt,
            keccak256(
                abi.encodePacked(
                    type(UsdWithdrawalOutputBuilder).creationCode,
                    abi.encode(SAFE_ERC20_TRANSFER, token)
                )
            )
        );
    }

    function getSafeErc20Transfer()
        external
        view
        override
        returns (ISafeERC20Transfer safeErc20Transfer)
    {
        return SAFE_ERC20_TRANSFER;
    }
}
