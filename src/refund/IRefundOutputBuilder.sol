// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {IVersionGetter} from "../common/IVersionGetter.sol";
import {IRefundOutputBuilderErrors} from "./IRefundOutputBuilderErrors.sol";

interface IRefundOutputBuilder is IRefundOutputBuilderErrors, IVersionGetter {
    /// @notice Build an output that, when executed by the application contract, reverts
    /// an unprocessed deposit by transferring the asset(s) back to the original sender
    /// account. This function will be called via the `STATICCALL` opcode, so any state
    /// changes such as contract creations, log emissions, storage writes, Ether transfers
    /// and self-destructions will revert the call and abort the execution of the refund
    /// output. These state-changing constraints are already checked by the Solidity
    /// compiler when implementing this function as either view or pure.
    /// @param appContract The application contract address
    /// @param inputSender The input sender
    /// @param inputPayload The input payload
    /// @return output The refund output
    /// @dev This function assumes the input box of the application indeed contains an
    /// input with such a sender and payload. May raise `UnknownInputSender`.
    function buildRefundOutput(
        address appContract,
        address inputSender,
        bytes calldata inputPayload
    ) external view returns (bytes memory output);
}
