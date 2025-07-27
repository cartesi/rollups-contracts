// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {EpochManager} from "./EpochManager.sol";
import {Inbox} from "./Inbox.sol";
import {Outbox} from "./Outbox.sol";

interface Application is EpochManager, Inbox, Outbox {}
