// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {WithdrawalConfig} from "../common/WithdrawalConfig.sol";

interface IApplicationFactoryErrors {
    /// @notice This error is raised when someone tries to deploy an application
    /// with invalid withdrawal configuration, in which the accounts drive is
    /// outside the bounds of the machine memory. This is forbidden at the contract
    /// level so that users and the node don't need to make this sanity check.
    /// @param withdrawalConfig The invalid withdrawal configuration
    error InvalidWithdrawalConfig(WithdrawalConfig withdrawalConfig);
}
