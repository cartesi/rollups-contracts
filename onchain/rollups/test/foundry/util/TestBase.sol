// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Test base contract
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";

contract TestBase is Test {
    /// @notice Guarantess `addr` is an address that can be mocked
    /// @dev Some addresses are reserved by Forge and should not be mocked
    modifier isMockable(address addr) {
        vm.assume(addr != VM_ADDRESS);
        vm.assume(addr != CONSOLE);
        vm.assume(addr != DEFAULT_SENDER);
        vm.assume(addr != DEFAULT_TEST_CONTRACT);
        vm.assume(addr != MULTICALL3_ADDRESS);
        _;
    }

    function contains(
        address[] memory array,
        address elem
    ) internal pure returns (bool) {
        for (uint256 i; i < array.length; ++i) {
            if (array[i] == elem) {
                return true;
            }
        }
        return false;
    }

    function generateAddresses(
        uint256 n
    ) internal pure returns (address[] memory) {
        address[] memory array = new address[](n);
        for (uint256 i; i < n; ++i) {
            array[i] = vm.addr(i + 1);
        }
        return array;
    }
}
