// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IERC165} from "@openzeppelin-contracts-5.2.0/utils/introspection/IERC165.sol";

import {Test} from "forge-std-1.9.6/src/Test.sol";

/// @notice Tests contracts that implement ERC-165
abstract contract ERC165Test is Test {
    /// @notice Whether the supported interfaces were registered.
    bool private _supportedInterfacesRegistered;

    /// @notice Mapping between interface id and whether the interface is supported.
    mapping(bytes4 => bool) private _isInterfaceSupported;

    function _registerSupportedInterfaces(bytes4[] memory supportedInterfaces) internal {
        require(
            _supportedInterfacesRegistered == false,
            "Supported interfaces already registered"
        );

        _isInterfaceSupported[type(IERC165).interfaceId] = true;

        for (uint256 i; i < supportedInterfaces.length; ++i) {
            _isInterfaceSupported[supportedInterfaces[i]] = true;
        }

        assertFalse(
            _isInterfaceSupported[0xffffffff],
            "Interface ID 0xffffffff should not be supported under ERC-165"
        );

        _supportedInterfacesRegistered = true;
    }

    function _testSupportsInterface(IERC165 erc165, bytes4 interfaceId) internal view {
        require(
            _supportedInterfacesRegistered == true,
            "Supported interfaces were not registered yet"
        );
        assertEq(
            erc165.supportsInterface(interfaceId),
            _isInterfaceSupported[interfaceId],
            "Interface ID support mismatch"
        );
    }
}
