// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";

import {IVersionGetter} from "../common/IVersionGetter.sol";
import {IWithdrawalOutputBuilder} from "./IWithdrawalOutputBuilder.sol";

interface IUsdWithdrawalOutputBuilder is IWithdrawalOutputBuilder, IVersionGetter {
    /// @notice Get the ERC-20 token used to generate withdrawal outputs.
    function token() external view returns (IERC20);
}
