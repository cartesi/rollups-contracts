// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {IPortal} from "./IPortal.sol";

/// @title Portal
/// @notice This contract serves as a base for all the other portals.
abstract contract Portal is IPortal {}
