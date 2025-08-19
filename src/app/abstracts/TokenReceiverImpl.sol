// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

/// @notice Receives tokens of several kinds.
abstract contract TokenReceiverImpl {
    /// @notice Accept Ether transfers.
    /// @dev If you wish to transfer Ether to an application while informing
    /// its backend, then please do so through the Ether portal contract.
    receive() external payable {}
}
