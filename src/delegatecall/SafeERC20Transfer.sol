// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";

contract SafeERC20Transfer {
    using SafeERC20 for IERC20;

    function safeTransfer(IERC20 token, address to, uint256 value) external {
        token.safeTransfer(to, value);
    }
}
