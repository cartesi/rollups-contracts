// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {Create2} from "@openzeppelin-contracts-5.2.0/utils/Create2.sol";

import {ITournamentFactory} from "prt-contracts/ITournamentFactory.sol";

import {DaveApp} from "../interfaces/DaveApp.sol";
import {DaveAppFactory} from "../interfaces/DaveAppFactory.sol";
import {DaveAppImpl} from "../concretes/DaveAppImpl.sol";

contract DaveAppFactoryImpl is DaveAppFactory {
    ITournamentFactory immutable _TOURNAMENT_FACTORY;

    constructor(ITournamentFactory tournamentFactory) {
        _TOURNAMENT_FACTORY = tournamentFactory;
    }

    function deployDaveApp(bytes32 genesisStateRoot, bytes32 salt)
        external
        override
        returns (DaveApp app)
    {
        app = new DaveAppImpl{salt: salt}(genesisStateRoot, _TOURNAMENT_FACTORY);
        emit DaveAppDeployed(app);
    }

    function computeDaveAppAddress(bytes32 genesisStateRoot, bytes32 salt)
        external
        view
        override
        returns (address appAddress)
    {
        return Create2.computeAddress(
            salt,
            keccak256(
                abi.encodePacked(
                    type(DaveAppImpl).creationCode,
                    abi.encode(genesisStateRoot, _TOURNAMENT_FACTORY)
                )
            )
        );
    }
}
