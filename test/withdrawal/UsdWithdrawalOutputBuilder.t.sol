// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Test} from "forge-std-1.9.6/src/Test.sol";

import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";

import {Outputs} from "src/common/Outputs.sol";
import {ISafeERC20Transfer} from "src/delegatecall/ISafeERC20Transfer.sol";
import {SafeERC20Transfer} from "src/delegatecall/SafeERC20Transfer.sol";
import {IWithdrawalOutputBuilder} from "src/withdrawal/IWithdrawalOutputBuilder.sol";
import {UsdWithdrawalOutputBuilder} from "src/withdrawal/UsdWithdrawalOutputBuilder.sol";

import {LibBytes} from "../util/LibBytes.sol";
import {SimpleERC20} from "../util/SimpleERC20.sol";

contract UsdWithdrawalOutputBuilderTest is Test {
    using LibBytes for bytes;

    IERC20 _usd;
    ISafeERC20Transfer _safeErc20Transfer;
    IWithdrawalOutputBuilder _withdrawalOutputBuilder;

    address immutable TOKEN_OWNER = vm.addr(1);
    uint256 constant TOTAL_SUPPLY = type(uint64).max;

    function setUp() external {
        _usd = new SimpleERC20(TOKEN_OWNER, TOTAL_SUPPLY);
        _safeErc20Transfer = new SafeERC20Transfer();
        _withdrawalOutputBuilder =
            new UsdWithdrawalOutputBuilder(_safeErc20Transfer, _usd);
    }

    function testBuildWithdrawalOutput(
        address user,
        uint64 balance,
        bytes calldata padding
    ) external view {
        bytes memory account = abi.encodePacked(_encodeAccount(user, balance), padding);
        assertGe(account.length, 28);
        bytes memory output = _withdrawalOutputBuilder.buildWithdrawalOutput(account);
        (bytes4 outputSelector, bytes memory outputArgs) = output.consumeBytes4();
        assertEq(outputSelector, Outputs.DelegateCallVoucher.selector);
        (address destination, bytes memory payload) =
            abi.decode(outputArgs, (address, bytes));
        assertEq(destination, address(_safeErc20Transfer));
        (bytes4 funcSelector, bytes memory callArgs) = payload.consumeBytes4();
        assertEq(funcSelector, ISafeERC20Transfer.safeTransfer.selector);
        (address token, address to, uint256 value) =
            abi.decode(callArgs, (address, address, uint256));
        assertEq(token, address(_usd));
        assertEq(to, user);
        assertEq(value, balance);
    }

    function testBuildWithdrawalOutputReverts(bytes calldata account) external {
        vm.assume(account.length < 28);
        vm.expectRevert("Account is too short");
        _withdrawalOutputBuilder.buildWithdrawalOutput(account);
    }

    function _encodeAccount(address user, uint64 balance)
        internal
        pure
        returns (bytes memory account)
    {
        account = new bytes(28);

        // Encode balance in little-endian order
        for (uint256 i; i < 8; ++i) {
            account[i] = bytes1(uint8((balance >> (8 * i)) & 0xff));
        }

        // Encode user address in big-endian order
        for (uint256 i; i < 20; ++i) {
            account[i + 8] = bytes1((bytes20(user) << (8 * i)) & bytes1(0xff));
        }
    }
}
