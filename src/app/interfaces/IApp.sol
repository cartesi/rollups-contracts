// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IAppInbox} from "./IAppInbox.sol";
import {IAppMetadata} from "./IAppMetadata.sol";
import {IAppOutbox} from "./IAppOutbox.sol";

interface IApp is IAppMetadata, IAppInbox, IAppOutbox {}
