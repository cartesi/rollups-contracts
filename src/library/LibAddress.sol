// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {AddressErrors} from "../common/AddressErrors.sol";
import {LibError} from "../library/LibError.sol";

library LibAddress {
    using LibError for bytes;

    /// @notice Perform a low level call and raise error if failed
    /// @param destination The address that will be called
    /// @param value The amount of Wei to be transferred through the call
    /// @param payload The payload, which—in the case of Solidity
    /// contracts—encodes a function call
    /// @dev Can be used to transfer Ether to EOAs by passing a non-zero
    /// value and an empty payload. Solidity contracts will accept such
    /// message calls through the receive() payable entrypoint.
    function safeCall(address destination, uint256 value, bytes memory payload) internal {
        address caller = address(this);
        uint256 balance = caller.balance;

        if (value > balance) {
            revert AddressErrors.InsufficientFunds(value, balance);
        }

        if (payload.length > 0 && destination.code.length == 0) {
            revert AddressErrors.TargetHasNoCode(destination);
        }

        bool success;
        bytes memory returndata;

        (success, returndata) = destination.call{value: value}(payload);

        if (!success) {
            returndata.raise();
        }
    }

    /// @notice Perform a delegate call and raise error if failed
    /// @param destination The address that will be called
    /// @param payload The payload, which—in the case of Solidity
    /// libraries—encodes a function call
    function safeDelegateCall(address destination, bytes memory payload) internal {
        if (destination.code.length == 0) {
            revert AddressErrors.TargetHasNoCode(destination);
        }

        bool success;
        bytes memory returndata;

        (success, returndata) = destination.delegatecall(payload);

        if (!success) {
            returndata.raise();
        }
    }
}
