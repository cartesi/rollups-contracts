// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/ERC20.sol";

contract TestFungibleToken is ERC20 {
    constructor() ERC20("Fungible", "FUN") {}

    /// @notice Mint fungible tokens for oneself.
    /// @param value The amount of fungible tokens to mint
    function mint(uint256 value) external {
        _mint(msg.sender, value);
    }

    /// @notice Mint fungible tokens.
    /// @param to The account that will receive the tokens
    /// @param value The amount of fungible tokens to mint
    /// @dev Compatible with `cast erc20 mint <TOKEN> <TO> <VALUE>`.
    function mint(address to, uint256 value) external {
        _mint(to, value);
    }

    /// @notice Burn fungible tokens from one's balance.
    /// @param value The amount of fungible tokens to burn
    /// @dev Compatible with `cast erc20 burn <TOKEN> <VALUE>`.
    function burn(uint256 value) external {
        _burn(msg.sender, value);
    }
}
