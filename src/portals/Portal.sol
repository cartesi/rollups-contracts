// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {RollupsContract} from "../common/RollupsContract.sol";
import {IApplication} from "../dapp/IApplication.sol";
import {IInputBox} from "../inputs/IInputBox.sol";
import {IPortal} from "./IPortal.sol";

/// @title Portal
/// @notice This contract serves as a base for all the other portals.
abstract contract Portal is IPortal, RollupsContract {
    /// @notice Add an input to an application's input box.
    /// @param appContract The application contract address
    /// @param payload The input payload
    function _addInput(address appContract, bytes memory payload) internal {
        _getInputBox(appContract).addInput(appContract, payload);
    }

    /// @notice Get an application's input box.
    /// @param appContract The application contract address
    /// @return The input box
    function _getInputBox(address appContract) internal view returns (IInputBox) {
        // We start by getting the input box address, as advertised
        // by the application contract. It might or might not contain code.

        address inputBox = _getInputBoxAddress(appContract);

        // We detect whether the input box address has any code as this can be
        // a common scenario faced by users and devs, which allows us to raise
        // the clearer `InputBoxNotDeployed` error, rather than an empty EVM error.

        if (inputBox.code.length == 0) {
            revert InputBoxNotDeployed(inputBox);
        }

        // If the input box address has code, we cast it as IInputBox.

        return IInputBox(inputBox);
    }

    /// @notice Get an application's input box address.
    /// @param appContract The application contract address
    /// @return The input box address
    function _getInputBoxAddress(address appContract) internal view returns (address) {
        // We detect whether the application contract address has any
        // code as this can be a common scenario faced by users and devs,
        // which allows us to raise the clearer `ApplicationNotDeployed` error,
        // rather than raising an `IllformedApplicationReturnData` error.

        if (appContract.code.length == 0) {
            revert ApplicationNotDeployed(appContract);
        }

        // We perform a low-level call to the application contract address
        // so that we can decode the return data in a more fault-tolerant way.

        (bool success, bytes memory returndata) =
            appContract.staticcall(abi.encodeCall(IApplication.getInputBox, ()));

        // If the call reverts, we wrap the error data in our `ApplicationReverted`
        // error so that malicious application cannot inject arbitrary errors.

        if (!success) {
            revert ApplicationReverted(appContract, returndata);
        }

        // If the call succeeds, we check whether the return data length
        // is 32 bytes. If not, we raise a `IllformedApplicationReturnData` error.

        if (returndata.length != 32) {
            revert IllformedApplicationReturnData(appContract, returndata);
        }

        // We decode the return data as a `uint256` value because decoding
        // it as a boolean could raise a low-level EVM code (if the encoded
        // value does not fit in a `uint160` value).

        uint256 returncode = abi.decode(returndata, (uint256));

        // We check whether the call returns a value that fits in a `uint160`.
        // If it does, we truncate it to a `uint160` and cast it as an `address`.
        // Otherwise, we raise an `IllformedApplicationReturnData` error.

        if (returncode <= type(uint160).max) {
            // forge-lint: disable-next-line(unsafe-typecast)
            return address(uint160(returncode));
        } else {
            revert IllformedApplicationReturnData(appContract, returndata);
        }
    }
}
