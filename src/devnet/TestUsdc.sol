// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/ERC20.sol";

import {BaseTestFungibleToken} from "./BaseTestFungibleToken.sol";

contract TestUsdc is ERC20, BaseTestFungibleToken {
    constructor() ERC20("USD Coin", "USDC") {}

    /// @inheritdoc ERC20
    /// @dev Overrides the default value of 18 from OpenZeppelin
    /// to better simulate the original USDC token on front-ends.
    function decimals() public pure override returns (uint8) {
        return 6;
    }
}
