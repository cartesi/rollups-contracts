// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

interface IAppEspressoConfig {
    /// @notice Get the Espresso block height.
    function espressoBlockHeight() external view returns (uint64);

    /// @notice Get the Espresso namespace ID.
    function espressoNamespaceId() external view returns (uint32);
}
