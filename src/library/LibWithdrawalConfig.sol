// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {CanonicalMachine} from "../common/CanonicalMachine.sol";
import {WithdrawalConfig} from "../common/WithdrawalConfig.sol";

library LibWithdrawalConfig {
    function isValid(WithdrawalConfig memory withdrawalConfig)
        internal
        pure
        returns (bool)
    {
        // The addition below cannot overflow because `3 * type(uint8).max <= type(uint256).max`.
        uint256 log2AccountsDriveSize = uint256(CanonicalMachine.LOG2_DATA_BLOCK_SIZE)
            + uint256(withdrawalConfig.log2MaxNumOfAccounts)
            + uint256(withdrawalConfig.log2LeavesPerAccount);

        // The addition below cannot overflow because `type(uint8).max + 1 <= type(uint256).max`.
        uint256 accountsDriveEndIndex =
            uint256(withdrawalConfig.accountsDriveStartIndex) + 1;

        // The left-shift below can overflow, so we need to check for overflow afterwards.
        uint256 accountsDriveEnd = accountsDriveEndIndex << log2AccountsDriveSize;
        if ((accountsDriveEnd >> log2AccountsDriveSize) != accountsDriveEndIndex) {
            return false;
        }

        // forge-lint: disable-next-line(incorrect-shift)
        uint256 memorySize = 1 << CanonicalMachine.LOG2_MEMORY_SIZE;

        // Check if the accounts drive would end past the machine memory boundaries.
        return (accountsDriveEnd <= memorySize);
    }
}
