// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/ERC20.sol";

import {BaseTestFungibleToken} from "./BaseTestFungibleToken.sol";

contract TestFungibleToken is BaseTestFungibleToken {
    constructor() ERC20("Fungible", "FUN") {}
}
