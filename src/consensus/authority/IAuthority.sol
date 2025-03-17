// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IOwnable} from "../../access/IOwnable.sol";
import {IConsensus} from "../IConsensus.sol";

/// @notice A consensus contract controlled by a single address, the owner.
interface IAuthority is IConsensus, IOwnable {}
