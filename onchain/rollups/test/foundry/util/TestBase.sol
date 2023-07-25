// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Test base contract
pragma solidity ^0.8.8;

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

    function sum(uint256[] memory array) internal pure returns (uint256) {
        uint256 total;
        for (uint256 i; i < array.length; ++i) {
            total += array[i];
        }
        return total;
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

    function generateArithmeticSequence(
        uint256 n
    ) internal pure returns (uint256[] memory) {
        return generateArithmeticSequence(n, 1);
    }

    function generateArithmeticSequence(
        uint256 n,
        uint256 a0
    ) internal pure returns (uint256[] memory) {
        return generateArithmeticSequence(n, a0, 1);
    }

    function generateArithmeticSequence(
        uint256 n,
        uint256 a0,
        uint256 d
    ) internal pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](n);
        uint256 a = a0;
        for (uint256 i; i < n; ++i) {
            array[i] = a;
            a += d;
        }
        return array;
    }

    function generateConstantArray(
        uint256 n,
        address value
    ) internal pure returns (address[] memory) {
        address[] memory array = new address[](n);
        for (uint256 i; i < n; ++i) {
            array[i] = value;
        }
        return array;
    }

    function generateConstantArray(
        uint256 n,
        uint256 value
    ) internal pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            array[i] = value;
        }
        return array;
    }
}
