// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IAppInbox} from "./IAppInbox.sol";
import {IAppOutbox} from "./IAppOutbox.sol";

interface IApp is IAppInbox, IAppOutbox {
    /// @notice Get Cartesi Rollups Contracts major version.
    function cartesiRollupsContractsMajorVersion() external pure returns (uint256);
}
