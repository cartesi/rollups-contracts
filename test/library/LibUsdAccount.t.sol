// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Test} from "forge-std-1.9.6/src/Test.sol";

import {LibUsdAccount} from "src/library/LibUsdAccount.sol";

library ExternalLibUsdAccount {
    /// @notice Tail-calls LibUsdAccount.decode.
    /// @dev Used to test errors raised by such function.
    function decode(bytes calldata account)
        external
        pure
        returns (address user, uint64 balance)
    {
        (user, balance) = LibUsdAccount.decode(account);
    }
}

contract LibUsdAccountTest is Test {
    function testEncodeDecode(address user, uint64 balance) external pure {
        bytes memory account = LibUsdAccount.encode(user, balance);
        assertEq(account.length, 28, "account length");
        (address user2, uint64 balance2) = ExternalLibUsdAccount.decode(account);
        assertEq(user, user2, "account user");
        assertEq(balance, balance2, "account balance");
    }

    function testDecode(bytes28 seed, bytes calldata padding) external pure {
        bytes memory account = abi.encodePacked(seed, padding);
        ExternalLibUsdAccount.decode(account);
    }

    function testDecodeRevertsAccountIsTooShort(uint256) external {
        bytes memory account = vm.randomBytes(vm.randomUint(0, 27));
        vm.expectRevert("Account is too short");
        ExternalLibUsdAccount.decode(account);
    }

    function testEncodeExample() external pure {
        address user = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        uint64 balance = 0x0123456789abcdef;
        assertEq(
            LibUsdAccount.encode(user, balance),
            hex"efcdab8967452301f39fd6e51aad88f6f4ce6ab8827279cfffb92266",
            "example account"
        );
    }

    function testDecodeExample() external pure {
        bytes memory account =
            hex"efcdab8967452301f39fd6e51aad88f6f4ce6ab8827279cfffb92266";
        (address user, uint64 balance) = ExternalLibUsdAccount.decode(account);
        assertEq(user, 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, "user");
        assertEq(balance, 0x0123456789abcdef, "balance");
    }

    function testEncodeZero() external pure {
        assertEq(
            LibUsdAccount.encode(address(0), uint64(0)), new bytes(28), "zero account"
        );
    }

    function testDecodeZero() external pure {
        bytes memory account = new bytes(28);
        (address user, uint64 balance) = ExternalLibUsdAccount.decode(account);
        assertEq(user, address(0), "user");
        assertEq(balance, uint64(0), "balance");
    }
}
