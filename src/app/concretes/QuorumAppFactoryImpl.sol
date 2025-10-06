// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {Create2} from "@openzeppelin-contracts-5.2.0/utils/Create2.sol";

import {EventEmitterImpl} from "../abstracts/EventEmitterImpl.sol";
import {QuorumAppFactory} from "../interfaces/QuorumAppFactory.sol";
import {QuorumAppImpl} from "../concretes/QuorumAppImpl.sol";
import {QuorumApp} from "../interfaces/QuorumApp.sol";

contract QuorumAppFactoryImpl is QuorumAppFactory, EventEmitterImpl {
    uint256 private _deployedAppCount;

    function deployQuorumApp(
        bytes32 genesisStateRoot,
        address[] calldata validators,
        bytes32 salt
    ) external override returns (QuorumApp app) {
        app = new QuorumAppImpl{salt: salt}(genesisStateRoot, validators);
        ++_deployedAppCount;
        emit QuorumAppDeployed(app);
    }

    function getDeployedAppCount()
        external
        view
        override
        returns (uint256 deployedAppCount)
    {
        return _deployedAppCount;
    }

    function computeQuorumAppAddress(
        bytes32 genesisStateRoot,
        address[] calldata validators,
        bytes32 salt
    ) external view override returns (address appAddress) {
        return Create2.computeAddress(
            salt,
            keccak256(
                abi.encodePacked(
                    type(QuorumAppImpl).creationCode,
                    abi.encode(genesisStateRoot, validators)
                )
            )
        );
    }
}
