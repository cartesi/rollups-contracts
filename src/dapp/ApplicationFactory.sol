// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {Clones} from "@openzeppelin-contracts-5.2.0/proxy/Clones.sol";

import {IApplicationFactory} from "./IApplicationFactory.sol";
import {IOutputsMerkleRootValidator} from "../consensus/IOutputsMerkleRootValidator.sol";
import {Application} from "./Application.sol";
import {IApplication} from "./IApplication.sol";

/// @title Application Factory
/// @notice Allows anyone to reliably deploy a new `IApplication` contract.
contract ApplicationFactory is IApplicationFactory {
    using Clones for address;

    Application immutable _impl;

    constructor(Application impl) {
        _impl = impl;
    }

    function newApplication(
        IOutputsMerkleRootValidator outputsMerkleRootValidator,
        address appOwner,
        bytes32 templateHash,
        bytes calldata dataAvailability
    ) external override returns (IApplication) {
        Application.Args memory args = _buildArgs(templateHash, dataAvailability);

        address clone = address(_impl).cloneWithImmutableArgs(abi.encode(args));
        Application appContract = Application(payable(clone));
        appContract.initialize(outputsMerkleRootValidator, appOwner);

        emit ApplicationCreated(
            outputsMerkleRootValidator,
            appOwner,
            templateHash,
            dataAvailability,
            appContract
        );

        return appContract;
    }

    function newApplication(
        IOutputsMerkleRootValidator outputsMerkleRootValidator,
        address appOwner,
        bytes32 templateHash,
        bytes calldata dataAvailability,
        bytes32 salt
    ) external override returns (IApplication) {
        salt = _computeSalt(outputsMerkleRootValidator, appOwner, salt);

        Application.Args memory args = _buildArgs(templateHash, dataAvailability);

        address clone =
            address(_impl).cloneDeterministicWithImmutableArgs(abi.encode(args), salt);
        Application appContract = Application(payable(clone));
        appContract.initialize(outputsMerkleRootValidator, appOwner);

        emit ApplicationCreated(
            outputsMerkleRootValidator,
            appOwner,
            templateHash,
            dataAvailability,
            appContract
        );

        return appContract;
    }

    function calculateApplicationAddress(
        IOutputsMerkleRootValidator outputsMerkleRootValidator,
        address appOwner,
        bytes32 templateHash,
        bytes calldata dataAvailability,
        bytes32 salt
    ) external view override returns (address) {
        salt = _computeSalt(outputsMerkleRootValidator, appOwner, salt);

        Application.Args memory args = _buildArgs(templateHash, dataAvailability);

        return address(_impl).predictDeterministicAddressWithImmutableArgs(
            abi.encode(args), salt
        );
    }

    function _buildArgs(bytes32 templateHash, bytes calldata dataAvailability)
        internal
        pure
        returns (Application.Args memory)
    {
        return Application.Args({
            templateHash: templateHash,
            dataAvailability: dataAvailability
        });
    }

    function _computeSalt(
        IOutputsMerkleRootValidator outputsMerkleRootValidator,
        address appOwner,
        bytes32 givenSalt
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(outputsMerkleRootValidator, appOwner, givenSalt));
    }
}
