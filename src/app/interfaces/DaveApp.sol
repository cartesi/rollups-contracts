// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IDataProvider} from "prt-contracts/IDataProvider.sol";

import {App} from "./App.sol";

interface DaveApp is App, IDataProvider {}
