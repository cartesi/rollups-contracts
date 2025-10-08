// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {EpochManager} from "./EpochManager.sol";
import {Inbox} from "./Inbox.sol";
import {Outbox} from "./Outbox.sol";

/// @notice The on-chain embodiment of a Cartesi Rollups application.
/// @dev This contract receives inputs, manages epochs, and validates/executes outputs.
/// Deposits (in Ether, ERC-20, ERC-721, and ERC-1155) must be made through portal contracts.
interface App is Outbox, EpochManager, Inbox {
    /// @notice Get the genesis state root of the application.
    /// @dev This information is useful to off-chain components to validate the genesis state
    /// of applications provided by third parties, since this state is be used by
    /// fraud-proof systems as a starting point and assumed to be correct.
    function getGenesisStateRoot() external view returns (bytes32);
}
