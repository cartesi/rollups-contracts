// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.27;

import {Clones} from "@openzeppelin-contracts-5.2.0/proxy/Clones.sol";

import {App} from "../interfaces/App.sol";
import {QuorumAppFactory} from "../interfaces/QuorumAppFactory.sol";
import {QuorumAppImpl} from "../concretes/QuorumAppImpl.sol";

contract QuorumAppFactoryImpl is QuorumAppFactory {
    using Clones for address;

    address immutable _IMPLEMENTATION;

    constructor(QuorumAppImpl implementation) {
        _IMPLEMENTATION = address(implementation);
    }

    function deployApp(
        bytes32 genesisStateRoot,
        address[] calldata validators,
        bytes32 salt
    ) external override returns (App) {
        bytes memory args = _encodeArgs(genesisStateRoot);
        salt = _mixSalt(salt, validators);
        address appAddress;
        appAddress = _IMPLEMENTATION.cloneDeterministicWithImmutableArgs(args, salt);
        QuorumAppImpl app = QuorumAppImpl(appAddress);
        app.initQuorum(validators);
        emit AppDeployed(app);
        return app;
    }

    function computeAppAddress(
        bytes32 genesisStateRoot,
        address[] calldata validators,
        bytes32 salt
    ) external view override returns (address appAddress) {
        bytes memory args = _encodeArgs(genesisStateRoot);
        salt = _mixSalt(salt, validators);
        return _IMPLEMENTATION.predictDeterministicAddressWithImmutableArgs(args, salt);
    }

    /// @notice ABI-encode arguments to embed in proxy contract's bytecode.
    /// @param genesisStateRoot The genesis state root
    function _encodeArgs(bytes32 genesisStateRoot)
        internal
        view
        returns (bytes memory args)
    {
        return abi.encode(
            QuorumAppImpl.Args({
                deploymentBlockNumber: block.number,
                genesisStateRoot: genesisStateRoot
            })
        );
    }

    /// @notice Mix salt with validators array to add entropy.
    /// @param salt The salt provided to the function
    /// @param validators The validators array
    /// @return newSalt A new salt, which takes into account all arguments
    function _mixSalt(bytes32 salt, address[] calldata validators)
        internal
        pure
        returns (bytes32 newSalt)
    {
        newSalt = keccak256(abi.encode(salt, validators));
    }
}
