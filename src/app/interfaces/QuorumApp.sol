// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {App} from "./App.sol";
import {Quorum} from "./Quorum.sol";

interface QuorumApp is App, Quorum {}
