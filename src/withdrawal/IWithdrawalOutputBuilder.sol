// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {IWithdrawalOutputBuilderErrors} from "./IWithdrawalOutputBuilderErrors.sol";

interface IWithdrawalOutputBuilder is IWithdrawalOutputBuilderErrors {
    /// @notice Build an output that, when executed by the application
    /// contract, transfers the funds of an account to its owner.
    /// The encoding of the account is application-specific but must comply
    /// with one convention: The account byte array must end with the account owner
    /// encoded as a 20-byte big-endian string. This convention allows the node to
    /// query an account by its owner from the accounts drive. The contract must not
    /// assume the account is well-formed. Instead, it should validate its length
    /// (possibly raising an `InvalidAccountSize` error) and its contents.
    /// This function will be called via the `STATICCALL` opcode,
    /// so any state changes such as contract creations,
    /// log emissions, storage writes, self-destructions
    /// and Ether transfers will revert the call and abort the execution
    /// of the withdrawal output. These state-changing constraints
    /// are already checked by the Solidity compiler when implementing
    /// this function as either view or pure.
    /// If the input sender is a contract, the withdrawal output may revert depending on
    /// the asset type (such as Ether, ERC-721, ERC-1155) and whether the depositor
    /// contract implements the necessary receiver entrypoint appropriately.
    /// @param appContract The application contract address
    /// @param account The input account
    /// @return output The withdrawal output
    /// @dev The application contract address might be necessary for vouchers that
    /// transfer assets from the application contract's account to the account owner's
    /// account (e.g. in the case of ERC-721 and ERC-1155 transfers).
    function buildWithdrawalOutput(address appContract, bytes calldata account)
        external
        view
        returns (bytes memory output);
}
