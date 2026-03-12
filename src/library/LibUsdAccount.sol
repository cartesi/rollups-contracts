// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

library LibUsdAccount {
    /// @notice Decode an account.
    /// @param account The account
    /// @return user The user address
    /// @return balance The user balance
    /// @dev Reverts if account is less than 28 bytes long.
    function decode(bytes calldata account)
        internal
        pure
        returns (address user, uint64 balance)
    {
        require(account.length >= 28, "Account is too short");

        user = address(uint160(bytes20(account[8:28])));

        for (uint256 i; i < 8; ++i) {
            balance |= uint64(uint256(uint8(account[i])) << (8 * i));
        }
    }

    /// @notice Encode an account.
    /// @param user The user address
    /// @param balance The user balance
    /// @return account The account
    function encode(address user, uint64 balance)
        internal
        pure
        returns (bytes memory account)
    {
        account = new bytes(28);

        for (uint256 i; i < 8; ++i) {
            account[i] = bytes1(uint8((balance >> (8 * i)) & 0xff));
        }

        for (uint256 i; i < 20; ++i) {
            account[i + 8] = bytes1((bytes20(user) << (8 * i)) & bytes1(0xff));
        }
    }
}
