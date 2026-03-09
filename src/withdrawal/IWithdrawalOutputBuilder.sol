// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

interface IWithdrawalOutputBuilder {
    /// @notice Build an output that, when executed by the application
    /// contract, transfers the funds of an account to its owner.
    /// The encoding of the account is application-specific.
    /// This function will be called via the `STATICCALL` opcode,
    /// so any state changes such as contract creations,
    /// log emissions, storage writes, self-destructions
    /// and Ether transfers will revert the call and abort the execution
    /// of the withdrawal output. These state-changing constraints
    /// are already checked by the Solidity compiler when implementing
    /// this function as either view or pure.
    function buildWithdrawalOutput(bytes calldata account)
        external
        view
        returns (bytes memory output);
}
