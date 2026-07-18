// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {IERC165} from "@openzeppelin-contracts-5.2.0/utils/introspection/IERC165.sol";

import {Test} from "forge-std-1.9.6/src/Test.sol";

/// @notice Tests contracts that implement ERC-165
abstract contract Erc165Test is Test {
    /// @notice Array of supported interfaces
    bytes4[] _supportedInterfaces;

    function _testSupportsInterface(IERC165 erc165) internal view {
        // Every ERC-165 compliant contract should support ERC-165 interface
        assertTrue(erc165.supportsInterface(type(IERC165).interfaceId));

        // Every ERC-165 compliant contract should not support 0xffffffff
        assertFalse(erc165.supportsInterface(0xffffffff));

        // Check supported interfaces
        for (uint256 i; i < _supportedInterfaces.length; ++i) {
            bytes4 interfaceId = _supportedInterfaces[i];
            assertTrue(erc165.supportsInterface(interfaceId));
        }

        // Check random unsupported interface
        while (true) {
            bytes4 interfaceId = vm.randomBytes4();
            bool isInterfaceSupported;
            for (uint256 i; i < _supportedInterfaces.length; ++i) {
                if (interfaceId == _supportedInterfaces[i]) {
                    isInterfaceSupported = true;
                    break;
                }
            }
            if (!isInterfaceSupported) {
                assertFalse(erc165.supportsInterface(interfaceId));
                break;
            }
        }
    }
}
