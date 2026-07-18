// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {RollupsTest} from "../util/RollupsTest.sol";
import {VersionGetterTestUtils} from "../util/VersionGetterTestUtils.sol";

contract SafeErc20TransferTest is RollupsTest, VersionGetterTestUtils {
    function testVersion() external view {
        _testVersion(_contracts.core.safeErc20Transfer);
    }
}
