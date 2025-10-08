// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {AppFactory} from "./AppFactory.sol";
import {DaveApp} from "./DaveApp.sol";
import {DeploymentInfoProvider} from "./DeploymentInfoProvider.sol";

/// @notice Deploys apps that use the Dave fraud-proof system as epoch manager.
interface DaveAppFactory is AppFactory, DeploymentInfoProvider {
    /// @notice This event is emitted whenever an app is deployed.
    /// @param app The application contract
    event DaveAppDeployed(DaveApp indexed app);

    /// @notice Deploy a new Dave-validated application.
    /// @param genesisStateRoot The genesis state root
    /// @param salt A 32-byte value used to generate the application address
    /// @return app The newly-deployed application
    function deployDaveApp(bytes32 genesisStateRoot, bytes32 salt)
        external
        returns (DaveApp app);

    /// @notice Compute a Dave-validated application address.
    /// @param genesisStateRoot The genesis state root
    /// @param salt A 32-byte value used to generate the application address
    /// @return appAddress The application address
    function computeDaveAppAddress(bytes32 genesisStateRoot, bytes32 salt)
        external
        view
        returns (address appAddress);
}
