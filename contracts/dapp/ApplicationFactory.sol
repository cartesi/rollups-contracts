// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

import {IApplicationFactory} from "./IApplicationFactory.sol";
import {IConsensus} from "../consensus/IConsensus.sol";
import {Application} from "./Application.sol";
import {IApplication} from "./IApplication.sol";

/// @title Application Factory
/// @notice Allows anyone to reliably deploy a new `IApplication` contract.
contract ApplicationFactory is IApplicationFactory {
    function newApplication(
        IConsensus consensus,
        address appOwner,
        bytes32 templateHash
    ) external override returns (IApplication) {
        IApplication appContract = new Application(
            consensus,
            appOwner,
            templateHash
        );

        emit ApplicationCreated(consensus, appOwner, templateHash, appContract);

        return appContract;
    }

    function newApplication(
        IConsensus consensus,
        address appOwner,
        bytes32 templateHash,
        bytes32 salt
    ) external override returns (IApplication) {
        IApplication appContract = new Application{salt: salt}(
            consensus,
            appOwner,
            templateHash
        );

        emit ApplicationCreated(consensus, appOwner, templateHash, appContract);

        return appContract;
    }

    function calculateApplicationAddress(
        IConsensus consensus,
        address appOwner,
        bytes32 templateHash,
        bytes32 salt
    ) external view override returns (address) {
        return
            Create2.computeAddress(
                salt,
                keccak256(
                    abi.encodePacked(
                        type(Application).creationCode,
                        abi.encode(consensus, appOwner, templateHash)
                    )
                )
            );
    }
}
