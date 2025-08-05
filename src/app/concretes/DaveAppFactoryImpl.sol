// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {Clones} from "@openzeppelin-contracts-5.2.0/proxy/Clones.sol";

import {ITournamentFactory} from "prt-contracts/ITournamentFactory.sol";

import {App} from "../interfaces/App.sol";
import {DaveAppFactory} from "../interfaces/DaveAppFactory.sol";
import {DaveAppImpl} from "../concretes/DaveAppImpl.sol";

contract DaveAppFactoryImpl is DaveAppFactory {
    using Clones for address;

    address immutable _IMPLEMENTATION;
    ITournamentFactory immutable _TOURNAMENT_FACTORY;

    constructor(DaveAppImpl implementation, ITournamentFactory tournamentFactory) {
        _IMPLEMENTATION = address(implementation);
        _TOURNAMENT_FACTORY = tournamentFactory;
    }

    function deployApp(bytes32 genesisStateRoot, bytes32 salt)
        external
        override
        returns (App app)
    {
        bytes memory args = _encodeArgs(genesisStateRoot);
        app = App(_IMPLEMENTATION.cloneDeterministicWithImmutableArgs(args, salt));
        emit AppDeployed(app);
    }

    function computeAppAddress(bytes32 genesisStateRoot, bytes32 salt)
        external
        view
        override
        returns (address appAddress)
    {
        bytes memory args = _encodeArgs(genesisStateRoot);
        return _IMPLEMENTATION.predictDeterministicAddressWithImmutableArgs(args, salt);
    }

    /// @notice ABI-encode arguments to embed in proxy contract's bytecode
    /// @param genesisStateRoot The genesis state root
    function _encodeArgs(bytes32 genesisStateRoot)
        internal
        view
        returns (bytes memory args)
    {
        return abi.encode(
            DaveAppImpl.Args({
                deploymentBlockNumber: block.number,
                genesisStateRoot: genesisStateRoot,
                tournamentFactory: _TOURNAMENT_FACTORY
            })
        );
    }
}
