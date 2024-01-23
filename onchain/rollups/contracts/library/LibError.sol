// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

library LibError {
    /// @notice Raise error data
    /// @param errordata Data returned by failed low-level call
    function raise(bytes memory errordata) internal pure {
        if (errordata.length == 0) {
            revert();
        } else {
            assembly {
                revert(add(32, errordata), mload(errordata))
            }
        }
    }
}
