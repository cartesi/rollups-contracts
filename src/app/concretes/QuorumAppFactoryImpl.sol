// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {Create2} from "@openzeppelin-contracts-5.2.0/utils/Create2.sol";

import {App} from "../interfaces/App.sol";
import {QuorumAppFactory} from "../interfaces/QuorumAppFactory.sol";
import {QuorumAppImpl} from "../concretes/QuorumAppImpl.sol";

contract QuorumAppFactoryImpl is QuorumAppFactory {
    function deployApp(
        bytes32 genesisStateRoot,
        address[] calldata validators,
        bytes32 salt
    ) external override returns (App app) {
        app = new QuorumAppImpl{salt: salt}(genesisStateRoot, validators);
        emit AppDeployed(app);
    }

    function computeAppAddress(
        bytes32 genesisStateRoot,
        address[] calldata validators,
        bytes32 salt
    ) external view override returns (address appAddress) {
        return Create2.computeAddress(
            salt,
            keccak256(
                abi.encodePacked(
                    type(QuorumAppImpl).creationCode,
                    abi.encode(
                        genesisStateRoot,
                        validators
                    )
                )
            )
        );
    }
}
