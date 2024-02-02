// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {TestBase} from "./TestBase.sol";

/// @notice Tests contracts that implement ERC-165
abstract contract ERC165Test is TestBase {
    /// @notice Get ERC-165 contract to be tested
    function getERC165Contract() public virtual returns (IERC165);

    /// @notice Get array of IDs of supported interfaces
    function getSupportedInterfaces() public virtual returns (bytes4[] memory);

    function testSupportsInterface() public {
        IERC165 erc165 = getERC165Contract();
        assertTrue(erc165.supportsInterface(type(IERC165).interfaceId));
        assertFalse(erc165.supportsInterface(0xffffffff));

        bytes4[] memory supportedInterfaces = getSupportedInterfaces();
        for (uint256 i; i < supportedInterfaces.length; ++i) {
            assertTrue(erc165.supportsInterface(supportedInterfaces[i]));
        }
    }

    function testSupportsInterface(bytes4 interfaceId) public {
        vm.assume(interfaceId != type(IERC165).interfaceId);

        bytes4[] memory supportedInterfaces = getSupportedInterfaces();
        for (uint256 i; i < supportedInterfaces.length; ++i) {
            vm.assume(interfaceId != supportedInterfaces[i]);
        }

        IERC165 erc165 = getERC165Contract();
        assertFalse(erc165.supportsInterface(interfaceId));
    }
}
