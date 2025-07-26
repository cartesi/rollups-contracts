// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {IPortal} from "./IPortal.sol";
import {IApp} from "../app/interfaces/IApp.sol";
import {IAppMetadata} from "../app/interfaces/IAppMetadata.sol";
import {Metadata} from "../common/Metadata.sol";

/// @title Portal
/// @notice This contract serves as a base for all the other portals.
abstract contract Portal is IPortal {
    /// @notice Ensures the application contract uses a compatible version of
    /// Cartesi Rollups Contracts, through a staticcall to the
    /// getCartesiRollupsContractsMajorVersion view function.
    function _ensureAppIsCompatible(IApp appContract) internal view {
        bool success;
        bytes memory payload;
        bytes memory returndata;

        // Encode the staticcall payload.
        payload = abi.encodeCall(IAppMetadata.getCartesiRollupsContractsMajorVersion, ());

        // Send the payload to the app contract via staticcall.
        (success, returndata) = address(appContract).staticcall(payload);

        // Ensure the staticcall was successful and returned well-formed data.
        require(success && returndata.length == 32, FailedApplicationVersionLookup());

        // Decode the major version from the return data.
        uint256 majorVersion = uint256(bytes32(returndata));

        // Ensure the obtained major version matches the expected one.
        require(majorVersion == Metadata.MAJOR_VERSION, IncompatibleApplicationVersion());
    }
}
