// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IAppInbox} from "./IAppInbox.sol";
import {IAppOutbox} from "./IAppOutbox.sol";
import {IAppVersion} from "./IAppVersion.sol";

interface IApp is IAppInbox, IAppOutbox, IAppVersion {}
