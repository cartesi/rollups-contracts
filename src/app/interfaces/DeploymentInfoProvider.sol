// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

/// @notice An interface that provides the deployment block number
/// of the contract for off-chain components to have a lower bound
/// when listening to events.
interface DeploymentInfoProvider {
    /// @notice Get the number of the block in which the contract was deployed.
    /// @dev This information is useful to off-chain components that need to listen to events
    /// emitted by contracts but use web3 providers that limit block ranges of
    /// `eth_getLogs` JSON-RPC requests.
    function getDeploymentBlockNumber() external view returns (uint256);
}
