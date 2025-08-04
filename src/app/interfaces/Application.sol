// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {EpochManager} from "./EpochManager.sol";
import {Inbox} from "./Inbox.sol";
import {Outbox} from "./Outbox.sol";

/// @notice A Cartesi Rollups application.
/// @dev This contract is responsible for receiving inputs,
/// managing epoch, and validating/executing outputs.
interface Application is EpochManager, Inbox, Outbox {
    /// @notice Get the number of the block in which the application contract was deployed.
    function getDeploymentBlockNumber() external view returns (uint256);
}
