// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Test} from "forge-std-1.9.6/src/Test.sol";

import {CanonicalMachine} from "src/common/CanonicalMachine.sol";
import {WithdrawalConfig} from "src/common/WithdrawalConfig.sol";

abstract contract WithdrawalConfigTestUtils is Test {
    function _makeWithdrawalConfigValidInPlace(WithdrawalConfig memory withdrawalConfig)
        internal
        pure
    {
        withdrawalConfig.log2LeavesPerAccount = uint8(
            bound(
                withdrawalConfig.log2LeavesPerAccount,
                0,
                CanonicalMachine.LOG2_MEMORY_SIZE - CanonicalMachine.LOG2_DATA_BLOCK_SIZE
            )
        );

        withdrawalConfig.log2MaxNumOfAccounts = uint8(
            bound(
                withdrawalConfig.log2MaxNumOfAccounts,
                0,
                CanonicalMachine.LOG2_MEMORY_SIZE - CanonicalMachine.LOG2_DATA_BLOCK_SIZE
                    - withdrawalConfig.log2LeavesPerAccount
            )
        );

        uint8 log2AccountsDriveSize = CanonicalMachine.LOG2_DATA_BLOCK_SIZE
            + withdrawalConfig.log2LeavesPerAccount
            + withdrawalConfig.log2MaxNumOfAccounts;

        // forge-lint: disable-start(incorrect-shift)
        withdrawalConfig.accountsDriveStartIndex = uint64(
            bound(
                withdrawalConfig.accountsDriveStartIndex,
                0,
                (1 << (CanonicalMachine.LOG2_MEMORY_SIZE - log2AccountsDriveSize)) - 1
            )
        );
        // forge-lint: disable-end(incorrect-shift)
    }

    function _makeWithdrawalConfigInvalidInPlace(WithdrawalConfig memory withdrawalConfig)
        internal
        view
    {
        if (vm.randomBool()) {
            if (
                withdrawalConfig.log2MaxNumOfAccounts
                    <= CanonicalMachine.LOG2_MEMORY_SIZE
                        - CanonicalMachine.LOG2_DATA_BLOCK_SIZE
            ) {
                withdrawalConfig.log2LeavesPerAccount = uint8(
                    bound(
                        withdrawalConfig.log2LeavesPerAccount,
                        CanonicalMachine.LOG2_MEMORY_SIZE
                            - CanonicalMachine.LOG2_DATA_BLOCK_SIZE
                            - withdrawalConfig.log2MaxNumOfAccounts + 1,
                        type(uint8).max
                    )
                );
            }
        } else {
            uint256 log2AccountsDriveSize = uint256(CanonicalMachine.LOG2_DATA_BLOCK_SIZE)
                + uint256(withdrawalConfig.log2LeavesPerAccount)
                + uint256(withdrawalConfig.log2MaxNumOfAccounts);

            // forge-lint: disable-start(incorrect-shift)
            if (log2AccountsDriveSize <= CanonicalMachine.LOG2_MEMORY_SIZE) {
                withdrawalConfig.accountsDriveStartIndex = uint64(
                    bound(
                        withdrawalConfig.accountsDriveStartIndex,
                        1 << (CanonicalMachine.LOG2_MEMORY_SIZE - log2AccountsDriveSize),
                        type(uint64).max
                    )
                );
            }
            // forge-lint: disable-end(incorrect-shift)
        }
    }
}
