// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {AppFactory} from "./AppFactory.sol";
import {DeploymentInfoProvider} from "./DeploymentInfoProvider.sol";
import {QuorumApp} from "./QuorumApp.sol";

/// @notice Deploys quorum-validated apps.
interface QuorumAppFactory is AppFactory, DeploymentInfoProvider {
    /// @notice This event is emitted whenever an app is deployed.
    /// @param app The application contract
    event QuorumAppDeployed(QuorumApp indexed app);

    /// @notice Deploy a new quorum-validated application.
    /// @param genesisStateRoot The genesis state root
    /// @param validators The array of validators
    /// @param salt A 32-byte value used to generate the application address
    /// @return app The newly-deployed application
    function deployQuorumApp(
        bytes32 genesisStateRoot,
        address[] calldata validators,
        bytes32 salt
    ) external returns (QuorumApp app);

    /// @notice Compute a quorum-validated application address.
    /// @param genesisStateRoot The genesis state root
    /// @param validators The array of validators
    /// @param salt A 32-byte value used to generate the application address
    /// @return appAddress The application address
    function computeQuorumAppAddress(
        bytes32 genesisStateRoot,
        address[] calldata validators,
        bytes32 salt
    ) external view returns (address appAddress);
}
