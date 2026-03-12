// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {WithdrawalConfig} from "src/common/WithdrawalConfig.sol";
import {LibWithdrawalConfig} from "src/library/LibWithdrawalConfig.sol";

import {WithdrawalConfigTestUtils} from "../util/WithdrawalConfigTestUtils.sol";

contract LibWithdrawalConfigTest is WithdrawalConfigTestUtils {
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
        _makeWithdrawalConfigValidInPlace(withdrawalConfig);
        assertTrue(LibWithdrawalConfig.isValid(withdrawalConfig));
    }

    /// @notice This test ensures that `isValid` returns false
    /// for some withdrawal configurations.
    function testIsValidFalse(WithdrawalConfig memory withdrawalConfig) external view {
        _makeWithdrawalConfigInvalidInPlace(withdrawalConfig);
        assertFalse(LibWithdrawalConfig.isValid(withdrawalConfig));
    }
}
