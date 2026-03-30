// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

interface IConsensusFactoryErrors {
    /// @notice This error is raised whenever a consensus would be deployed
    /// with zero as epoch length. This is forbidden because this would lead
    /// to a division-by-zero error when calculating the epoch index of any
    /// given block number, which is given by `block.number / epochLength`.
    error ZeroEpochLength();
}
