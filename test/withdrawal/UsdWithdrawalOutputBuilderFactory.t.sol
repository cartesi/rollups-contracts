// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Test} from "forge-std-1.9.6/src/Test.sol";
import {Vm} from "forge-std-1.9.6/src/Vm.sol";

import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";

import {Outputs} from "src/common/Outputs.sol";
import {ISafeERC20Transfer} from "src/delegatecall/ISafeERC20Transfer.sol";
import {SafeERC20Transfer} from "src/delegatecall/SafeERC20Transfer.sol";
import {
    IUsdWithdrawalOutputBuilder
} from "src/withdrawal/IUsdWithdrawalOutputBuilder.sol";
import {
    IUsdWithdrawalOutputBuilderFactory
} from "src/withdrawal/IUsdWithdrawalOutputBuilderFactory.sol";
import {
    IWithdrawalOutputBuilderErrors
} from "src/withdrawal/IWithdrawalOutputBuilderErrors.sol";
import {
    UsdWithdrawalOutputBuilderFactory
} from "src/withdrawal/UsdWithdrawalOutputBuilderFactory.sol";

import {LibBytes} from "../util/LibBytes.sol";
import {VersionGetterTestUtils} from "../util/VersionGetterTestUtils.sol";

contract UsdWithdrawalOutputBuilderTest is Test, VersionGetterTestUtils {
    using LibBytes for bytes;

    ISafeERC20Transfer _safeErc20Transfer;
    IUsdWithdrawalOutputBuilderFactory _factory;

    function setUp() external {
        _safeErc20Transfer = new SafeERC20Transfer();
        _factory = new UsdWithdrawalOutputBuilderFactory(_safeErc20Transfer);
    }

    function testVersion() external view {
        _testVersion(_factory);
    }

    function testGetSafeErc20Transfer() external view {
        assertEq(address(_factory.getSafeErc20Transfer()), address(_safeErc20Transfer));
    }

    function testNewUsdWithdrawalOutputBuilder(IERC20 token, bytes32 salt) external {
        address precalculatedAddress =
            _factory.calculateUsdWithdrawalOutputBuilderAddress(token, salt);

        vm.recordLogs();
        IUsdWithdrawalOutputBuilder usdWithdrawalOutputBuilder;
        usdWithdrawalOutputBuilder = _factory.newUsdWithdrawalOutputBuilder(token, salt);

        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(
            precalculatedAddress,
            address(usdWithdrawalOutputBuilder),
            "calculateUsdWithdrawalOutputBuilderAddress(...) != newUsdWithdrawalOutputBuilder(...)"
        );

        uint256 numOfUsdWithdrawalOutputBuilderCreatedEvents;

        for (uint256 i; i < logs.length; ++i) {
            Vm.Log memory log = logs[i];
            if (log.emitter == address(_factory)) {
                if (
                    log.topics[0]
                        == IUsdWithdrawalOutputBuilderFactory.UsdWithdrawalOutputBuilderCreated
                            .selector
                ) {
                    address arg1 = abi.decode(log.data, (address));
                    assertEq(arg1, address(usdWithdrawalOutputBuilder));
                    ++numOfUsdWithdrawalOutputBuilderCreatedEvents;
                } else {
                    revert("unexpected event selector");
                }
            } else {
                revert("unexpected log emitter");
            }
        }

        assertEq(numOfUsdWithdrawalOutputBuilderCreatedEvents, 1);

        assertEq(
            _factory.calculateUsdWithdrawalOutputBuilderAddress(token, salt),
            precalculatedAddress,
            "calculateUsdWithdrawalOutputBuilderAddress(...) is not a pure function"
        );

        // Cannot deploy a contract with the same salt twice
        try _factory.newUsdWithdrawalOutputBuilder(token, salt) {
            revert("second deterministic deployment did not revert");
        } catch (bytes memory errorData) {
            assertEq(
                errorData,
                new bytes(0),
                "second deterministic deployment did not revert with empty error data"
            );
        }

        _testVersion(usdWithdrawalOutputBuilder);

        assertEq(
            address(usdWithdrawalOutputBuilder.token()),
            address(token),
            "token() != token"
        );
    }

    function testBuildWithdrawalOutput(
        address appContract,
        IERC20 token,
        bytes32 salt,
        address user,
        uint64 balance,
        bytes calldata padding
    ) external {
        IUsdWithdrawalOutputBuilder usdWithdrawalOutputBuilder;
        usdWithdrawalOutputBuilder = _factory.newUsdWithdrawalOutputBuilder(token, salt);
        bytes memory account = abi.encodePacked(_encodeAccount(user, balance), padding);
        assertGe(account.length, 28);
        bytes memory output;
        output = usdWithdrawalOutputBuilder.buildWithdrawalOutput(appContract, account);
        (bytes4 outputSelector, bytes memory outputArgs) = output.consumeBytes4();
        assertEq(outputSelector, Outputs.DelegateCallVoucher.selector);
        (address destination, bytes memory payload) =
            abi.decode(outputArgs, (address, bytes));
        assertEq(destination, address(_safeErc20Transfer));
        (bytes4 funcSelector, bytes memory callArgs) = payload.consumeBytes4();
        assertEq(funcSelector, ISafeERC20Transfer.safeTransfer.selector);
        (address token2, address to, uint256 value) =
            abi.decode(callArgs, (address, address, uint256));
        assertEq(token2, address(token));
        assertEq(to, user);
        assertEq(value, balance);
    }

    function testBuildWithdrawalOutputReverts(
        address appContract,
        IERC20 token,
        bytes32 salt
    ) external {
        IUsdWithdrawalOutputBuilder usdWithdrawalOutputBuilder;
        usdWithdrawalOutputBuilder = _factory.newUsdWithdrawalOutputBuilder(token, salt);
        uint64 accountSize = uint64(vm.randomUint(0, 27));
        bytes memory account = vm.randomBytes(accountSize);
        vm.expectRevert(_encodeAccountTooShort(accountSize));
        usdWithdrawalOutputBuilder.buildWithdrawalOutput(appContract, account);
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

    function _encodeAccountTooShort(uint64 attemptedAccountSize)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IWithdrawalOutputBuilderErrors.AccountTooShort.selector,
            attemptedAccountSize,
            28
        );
    }
}
