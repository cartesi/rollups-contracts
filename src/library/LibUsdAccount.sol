// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {IWithdrawalOutputBuilderErrors} from "../withdrawal/IWithdrawalOutputBuilderErrors.sol";

library LibUsdAccount {
    uint64 constant ACCOUNT_SIZE = 32;

    /// @notice Decode an account.
    /// @param account The account
    /// @return user The user address
    /// @return balance The user balance
    /// @dev Reverts if account is not 32 bytes long.
    function decode(bytes calldata account)
        internal
        pure
        returns (address user, uint96 balance)
    {
        _checkAccountSize(account.length);

        user = address(uint160(bytes20(account[12:32])));

        for (uint256 i; i < 12; ++i) {
            balance |= uint96(uint256(uint8(account[i])) << (8 * i));
        }
    }

    /// @notice Encode an account.
    /// @param user The user address
    /// @param balance The user balance
    /// @return account The account
    function encode(address user, uint96 balance)
        internal
        pure
        returns (bytes memory account)
    {
        account = new bytes(ACCOUNT_SIZE);

        for (uint256 i; i < 12; ++i) {
            account[i] = bytes1(uint8((balance >> (8 * i)) & 0xff));
        }

        for (uint256 i; i < 20; ++i) {
            account[i + 12] = bytes1((bytes20(user) << (8 * i)) & bytes1(0xff));
        }
    }

    function _checkAccountSize(uint256 accountSize) internal pure {
        require(
            accountSize == ACCOUNT_SIZE,
            IWithdrawalOutputBuilderErrors.InvalidAccountSize(accountSize, ACCOUNT_SIZE)
        );
    }
}
