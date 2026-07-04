// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {IVersionGetter} from "../common/IVersionGetter.sol";
import {IApplicationChecker} from "../dapp/IApplicationChecker.sol";

/// @title Portal interface
interface IPortal is IVersionGetter, IApplicationChecker {}
