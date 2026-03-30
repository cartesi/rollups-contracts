// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

interface IQuorumFactoryErrors {
    /// @notice This error is raised whenever one tries to deploy a Quorum
    /// with the zero address as one of the validators. This is forbidden
    /// because we reserve the zero address as a sentinel value for
    /// non-validators (when consulting the `validatorById` function).
    error ZeroAddressValidator();

    /// @notice This error is raised whenever someone deploys a Quorum
    /// with an empty array of validators. This is forbidden because without
    /// validators, the Quorum contract would be essentially dead, indicating
    /// a mistake from the deployer.
    error EmptyQuorum();
}
