// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

/// @notice The interface of OpenZeppelin's `Ownable` contract.
interface IOwnable {
    /// @notice Get address of current owner.
    function owner() external view returns (address);

    /// @notice Renounce the ownership.
    /// @dev Can only be called by the current owner.
    function renounceOwnership() external;

    /// @notice Transfer ownership to a new owner.
    /// @param newOwner The address of the new owner
    /// @dev Can only be called by the current owner.
    function transferOwnership(address newOwner) external;
}
