// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Test} from "forge-std-1.9.6/src/Test.sol";

import {ISafeERC20Transfer} from "src/delegatecall/ISafeERC20Transfer.sol";
import {SafeERC20Transfer} from "src/delegatecall/SafeERC20Transfer.sol";

import {VersionGetterTestUtils} from "../util/VersionGetterTestUtils.sol";

contract SafeERC20TransferTest is Test, VersionGetterTestUtils {
    ISafeERC20Transfer _safeErc20Transfer;

    function setUp() external {
        _safeErc20Transfer = new SafeERC20Transfer();
    }

    function testVersion() external view {
        _testVersion(_safeErc20Transfer);
    }
}
