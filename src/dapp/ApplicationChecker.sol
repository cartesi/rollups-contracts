// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IApplicationChecker} from "./IApplicationChecker.sol";
import {IApplicationForeclosure} from "./IApplicationForeclosure.sol";

abstract contract ApplicationChecker is IApplicationChecker {
    /// @notice Ensure that a given application is not foreclosed.
    /// @param appContract The application contract address
    function _ensureIsNotForeclosed(address appContract) internal view {
        // We detect whether the application contract address has any
        // code as this can be a common scenario faced by users and devs,
        // which allows us to raise the clearer `ApplicationNotDeployed` error,
        // rather than raising an `IllformedApplicationReturnData` error.

        if (appContract.code.length == 0) {
            revert ApplicationNotDeployed(appContract);
        }

        // We perform a low-level call to the application contract address
        // so that we can decode the return data in a more fault-tolerant way.

        (bool success, bytes memory returndata) = appContract.staticcall(
            abi.encodeCall(IApplicationForeclosure.isForeclosed, ())
        );

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
        // value is neither a 0 or a 1).

        uint256 returncode = abi.decode(returndata, (uint256));

        // We check whether the call returns 0 (false), 1 (true), or something else.
        // If it returns 0 (the app is NOT foreclosed), we accept the input.
        // If it returns 1 (app IS foreclosed), we raise an `ApplicationForeclosed` error.
        // If it returns something else, we raise a `IllformedApplicationReturnData` error.

        if (returncode == 1) {
            revert ApplicationForeclosed(appContract);
        } else if (returncode != 0) {
            revert IllformedApplicationReturnData(appContract, returndata);
        }
    }

    /// @notice A modifier that ensures an application is not foreclosed.
    /// @param appContract The application contract address
    modifier notForeclosed(address appContract) {
        _ensureIsNotForeclosed(appContract);
        _;
    }
}
