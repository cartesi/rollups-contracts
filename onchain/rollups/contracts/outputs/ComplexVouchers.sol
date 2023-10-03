// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {ICartesiDApp} from "../dapp/ICartesiDApp.sol";

/// @title Complex Vouchers
/// @notice This contract enables DApps to emit vouchers with more complex behavior.
/// @dev Any assets transferred to this contract are susceptible to being stolen.
contract ComplexVouchers {
    /// @param destination The address to be called
    /// @param payload The data to be forwarded to the destination
    struct Voucher {
        address destination;
        bytes payload;
    }

    /// @notice Executes an atomic sequence of vouchers.
    /// @param _vouchers Array of vouchers
    /// @dev Reverts if any of the vouchers reverts.
    function executeAtomicVoucherSequence(
        Voucher[] calldata _vouchers
    ) external {
        for (uint256 i; i < _vouchers.length; i++) {
            Voucher memory voucher = _vouchers[i];
            (bool success, ) = voucher.destination.call(voucher.payload);
            require(success);
        }
    }

    /// @notice Check if a voucher was executed already.
    /// @param _dapp The DApp that emitted the voucher
    /// @param _inputIndex The input index
    /// @param _outputIndex The output index
    function checkIfVoucherWasExecuted(
        ICartesiDApp _dapp,
        uint256 _inputIndex,
        uint256 _outputIndex
    ) external view {
        require(_dapp.wasVoucherExecuted(_inputIndex, _outputIndex));
    }

    /// @notice Check if `tx.origin` is in an array of addresses.
    /// @param _addresses Array of addresses
    function checkIfTxOriginIsInArray(
        address[] calldata _addresses
    ) external view {
        require(_find(tx.origin, _addresses));
    }

    /// @notice Checks if the block timestamp is greater or equal to the provided timestamp.
    /// @param _ts timestamp lower bound
    function checkTimestampLowerBound(uint256 _ts) external view {
        require(_ts <= block.timestamp);
    }

    /// @notice Checks if the block timestamp is less than the provided timestamp.
    /// @param _ts timestamp upper bound
    function checkTimestampUpperBound(uint256 _ts) external view {
        require(block.timestamp < _ts);
    }

    /// @notice Check if an array of addresses contain another address
    /// @param haystack The list of addresses
    /// @param needle The address
    function _find(
        address needle,
        address[] calldata haystack
    ) internal pure returns (bool) {
        for (uint256 i; i < haystack.length; i++) {
            if (haystack[i] == needle) {
                return true;
            }
        }
        return false;
    }
}
