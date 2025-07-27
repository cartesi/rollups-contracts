// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

/// @notice Provides useful metadata for off-chain components
/// listening to events emitted by such contracts.
interface EventEmitter {
    /// @notice Get the number of the block in which the contract was deployed.
    /// @dev Useful for off-chain components that use web3 providers that limit
    /// the block ranges of `eth_getLogs` requests.
    function getDeploymentBlockNumber() external view returns (uint256);
}
