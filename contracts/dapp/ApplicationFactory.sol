// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

import {IApplicationFactory} from "./IApplicationFactory.sol";
import {IConsensus} from "../consensus/IConsensus.sol";
import {IInputBox} from "../inputs/IInputBox.sol";
import {IPortal} from "../portals/IPortal.sol";
import {Application} from "./Application.sol";

/// @title Application Factory
/// @notice Allows anyone to reliably deploy a new `Application` contract.
contract ApplicationFactory is IApplicationFactory {
    function newApplication(
        IConsensus consensus,
        IInputBox inputBox,
        IPortal[] memory portals,
        address appOwner,
        bytes32 templateHash
    ) external override returns (Application) {
        Application app = new Application(
            consensus,
            inputBox,
            portals,
            appOwner,
            templateHash
        );

        emit ApplicationCreated(
            consensus,
            inputBox,
            portals,
            appOwner,
            templateHash,
            app
        );

        return app;
    }

    function newApplication(
        IConsensus consensus,
        IInputBox inputBox,
        IPortal[] memory portals,
        address appOwner,
        bytes32 templateHash,
        bytes32 salt
    ) external override returns (Application) {
        Application app = new Application{salt: salt}(
            consensus,
            inputBox,
            portals,
            appOwner,
            templateHash
        );

        emit ApplicationCreated(
            consensus,
            inputBox,
            portals,
            appOwner,
            templateHash,
            app
        );

        return app;
    }

    function calculateApplicationAddress(
        IConsensus consensus,
        IInputBox inputBox,
        IPortal[] memory portals,
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
                        abi.encode(
                            consensus,
                            inputBox,
                            portals,
                            appOwner,
                            templateHash
                        )
                    )
                )
            );
    }
}
