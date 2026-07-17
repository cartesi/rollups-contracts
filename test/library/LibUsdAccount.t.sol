// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {Test} from "forge-std-1.9.6/src/Test.sol";

import {LibUsdAccount} from "src/library/LibUsdAccount.sol";
import {IWithdrawalOutputBuilderErrors} from "src/withdrawal/IWithdrawalOutputBuilderErrors.sol";

library ExternalLibUsdAccount {
    /// @notice Tail-calls LibUsdAccount.decode.
    /// @dev Used to test errors raised by such function.
    function decode(bytes calldata account)
        external
        pure
        returns (address user, uint96 balance)
    {
        (user, balance) = LibUsdAccount.decode(account);
    }
}

contract LibUsdAccountTest is Test {
    function testEncodeDecode(address user, uint96 balance) external pure {
        bytes memory account = LibUsdAccount.encode(user, balance);
        assertEq(account.length, 32, "account length");
        (address user2, uint96 balance2) = ExternalLibUsdAccount.decode(account);
        assertEq(user, user2, "account user");
        assertEq(balance, balance2, "account balance");
    }

    function testDecode(bytes32 seed) external pure {
        bytes memory account = abi.encodePacked(seed);
        ExternalLibUsdAccount.decode(account);
    }

    function testDecodeRevertsInvalidAccountSize(uint16 accountSize) external {
        vm.assume(accountSize != 32);
        bytes memory account = vm.randomBytes(accountSize);
        vm.expectRevert(_encodeInvalidAccountSize(accountSize));
        ExternalLibUsdAccount.decode(account);
    }

    function testEncodeExample() external pure {
        address user = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        uint96 balance = 0x0123456789abcdef01234567;
        assertEq(
            LibUsdAccount.encode(user, balance),
            hex"67452301efcdab8967452301f39fd6e51aad88f6f4ce6ab8827279cfffb92266",
            "example account"
        );
    }

    function testDecodeExample() external pure {
        bytes memory account =
            hex"67452301efcdab8967452301f39fd6e51aad88f6f4ce6ab8827279cfffb92266";
        (address user, uint96 balance) = ExternalLibUsdAccount.decode(account);
        assertEq(user, 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, "user");
        assertEq(balance, 0x0123456789abcdef01234567, "balance");
    }

    function testEncodeZero() external pure {
        assertEq(
            LibUsdAccount.encode(address(0), uint96(0)), new bytes(32), "zero account"
        );
    }

    function testDecodeZero() external pure {
        bytes memory account = new bytes(32);
        (address user, uint96 balance) = ExternalLibUsdAccount.decode(account);
        assertEq(user, address(0), "user");
        assertEq(balance, uint96(0), "balance");
    }

    function _encodeInvalidAccountSize(uint256 attemptedAccountSize)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IWithdrawalOutputBuilderErrors.InvalidAccountSize.selector,
            attemptedAccountSize,
            32
        );
    }
}
