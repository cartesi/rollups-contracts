// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {Create2} from "@openzeppelin-contracts-5.2.0/utils/Create2.sol";

import {IOutputsMerkleRootValidator} from "../consensus/IOutputsMerkleRootValidator.sol";
import {Application} from "./Application.sol";
import {IApplication} from "./IApplication.sol";
import {IApplicationFactory} from "./IApplicationFactory.sol";

/// @title Application Factory
/// @notice Allows anyone to reliably deploy a new `IApplication` contract.
contract ApplicationFactory is IApplicationFactory {
    function newApplication(
        IOutputsMerkleRootValidator outputsMerkleRootValidator,
        address appOwner,
        bytes32 templateHash,
        bytes calldata dataAvailability
    ) external override returns (IApplication) {
        IApplication appContract = new Application(
            outputsMerkleRootValidator, appOwner, templateHash, dataAvailability
        );

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
        IApplication appContract = new Application{
            salt: salt
        }(outputsMerkleRootValidator, appOwner, templateHash, dataAvailability);

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
        return Create2.computeAddress(
            salt,
            keccak256(
                abi.encodePacked(
                    type(Application).creationCode,
                    abi.encode(
                        outputsMerkleRootValidator,
                        appOwner,
                        templateHash,
                        dataAvailability
                    )
                )
            )
        );
    }
}
