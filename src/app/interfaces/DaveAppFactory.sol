// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {App} from "./App.sol";

/// @notice Deploys apps validated using the Dave fraud-proof system.
interface DaveAppFactory {
    /// @notice This event is emitted whenever an app is deployed.
    /// @param app The application contract
    event AppDeployed(App indexed app);

    /// @notice Deploy a new application.
    /// @param genesisStateRoot The genesis state root
    /// @param salt A 32-byte value used to generate the application address
    /// @return app The newly-deployed application
    function deployApp(bytes32 genesisStateRoot, bytes32 salt)
        external
        returns (App app);

    /// @notice Compute an application address.
    /// @param genesisStateRoot The genesis state root
    /// @param salt A 32-byte value used to generate the application address
    /// @return appAddress The application address
    function computeAppAddress(bytes32 genesisStateRoot, bytes32 salt)
        external
        view
        returns (address appAddress);
}
