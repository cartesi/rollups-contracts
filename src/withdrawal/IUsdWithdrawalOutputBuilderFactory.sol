// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";

import {IVersionGetter} from "../common/IVersionGetter.sol";
import {ISafeERC20Transfer} from "../delegatecall/ISafeERC20Transfer.sol";
import {IUsdWithdrawalOutputBuilder} from "./IUsdWithdrawalOutputBuilder.sol";

/// @title USD Withdrawal Output Builder Factory interface
/// @dev For greater simplicity, this factory only supports deterministic deployments.
/// Given that USD withdrawal output builders are stateless contracts, it should not matter
/// whether you deploy one yourself or use an already deployed one with the same token.
interface IUsdWithdrawalOutputBuilderFactory is IVersionGetter {
    // Events

    /// @notice A new USD withdrawal output builder was deployed.
    /// @param usdWithdrawalOutputBuilder The USD withdrawal output builder
    /// @dev MUST be triggered on a successful call to `newUsdWithdrawalOutputBuilder`.
    event UsdWithdrawalOutputBuilderCreated(IUsdWithdrawalOutputBuilder usdWithdrawalOutputBuilder);

    // Permissionless functions

    /// @notice Deploy a new USD withdrawal output builder deterministically.
    /// @param token The USD-like ERC-20 token
    /// @param salt The salt used to deterministically generate the contract address
    /// @return usdWithdrawalOutputBuilder The USD withdrawal output builder
    function newUsdWithdrawalOutputBuilder(IERC20 token, bytes32 salt)
        external
        returns (IUsdWithdrawalOutputBuilder usdWithdrawalOutputBuilder);

    /// @notice Calculate the address of a USD withdrawal output builder to be deployed deterministically.
    /// @param token The USD-like ERC-20 token
    /// @param salt The salt used to deterministically generate the contract address
    /// @return usdWithdrawalOutputBuilderAddress The deterministic USD withdrawal output builder address
    function calculateUsdWithdrawalOutputBuilderAddress(IERC20 token, bytes32 salt)
        external
        view
        returns (address usdWithdrawalOutputBuilderAddress);

    /// @notice Get the safe ERC-20 transfer contract passed down to the USD withdrawal
    /// output builders. This contract is used as delegate-call voucher destination.
    /// @return safeErc20Transfer The safe ERC-20 transfer contract
    function getSafeErc20Transfer()
        external
        view
        returns (ISafeERC20Transfer safeErc20Transfer);
}
