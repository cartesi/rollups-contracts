// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Test} from "forge-std-1.9.6/src/Test.sol";

import {CanonicalMachine} from "src/common/CanonicalMachine.sol";
import {WithdrawalConfig} from "src/common/WithdrawalConfig.sol";
import {LibWithdrawalConfig} from "src/library/LibWithdrawalConfig.sol";

contract LibWithdrawalConfigTest is Test {
    /// @notice This test ensures that `isValid` never reverts,
    /// regardless of the input withdrawal configuration.
    function testIsValidCompleteness(WithdrawalConfig memory withdrawalConfig)
        external
        pure
        returns (bool)
    {
        return LibWithdrawalConfig.isValid(withdrawalConfig);
    }

    /// @notice This test ensures that `isValid` returns true
    /// for some withdrawal configurations.
    function testIsValidTrue(WithdrawalConfig memory withdrawalConfig) external pure {
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

        assertTrue(LibWithdrawalConfig.isValid(withdrawalConfig));
    }

    /// @notice This test ensures that `isValid` returns false
    /// for withdrawal configurations in which the accounts drive is too big.
    function testIsValidFalseAccountsDriveTooBig(WithdrawalConfig memory withdrawalConfig)
        external
        pure
    {
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

        assertFalse(LibWithdrawalConfig.isValid(withdrawalConfig));
    }

    /// @notice This test ensures that `isValid` returns false
    /// for withdrawal configurations in which the accounts drive is outside memory bounds.
    function testIsValidFalseAccountsDriveOutsideBounds(WithdrawalConfig memory withdrawalConfig)
        external
        pure
    {
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

        assertFalse(LibWithdrawalConfig.isValid(withdrawalConfig));
    }
}
