// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

import {IApplicationFactory} from "./IApplicationFactory.sol";
import {IConsensus} from "../consensus/IConsensus.sol";
import {IInputBox} from "../inputs/IInputBox.sol";
import {IInputRelay} from "../inputs/IInputRelay.sol";
import {Application} from "./Application.sol";

/// @title Application Factory
/// @notice Allows anyone to reliably deploy a new `Application` contract.
contract ApplicationFactory is IApplicationFactory {
    function newApplication(
        IConsensus _consensus,
        IInputBox _inputBox,
        IInputRelay[] memory _inputRelays,
        address _appOwner,
        bytes32 _templateHash
    ) external override returns (Application) {
        Application app = new Application(
            _consensus,
            _inputBox,
            _inputRelays,
            _appOwner,
            _templateHash
        );

        emit ApplicationCreated(
            _consensus,
            _inputBox,
            _inputRelays,
            _appOwner,
            _templateHash,
            app
        );

        return app;
    }

    function newApplication(
        IConsensus _consensus,
        IInputBox _inputBox,
        IInputRelay[] memory _inputRelays,
        address _appOwner,
        bytes32 _templateHash,
        bytes32 _salt
    ) external override returns (Application) {
        Application app = new Application{salt: _salt}(
            _consensus,
            _inputBox,
            _inputRelays,
            _appOwner,
            _templateHash
        );

        emit ApplicationCreated(
            _consensus,
            _inputBox,
            _inputRelays,
            _appOwner,
            _templateHash,
            app
        );

        return app;
    }

    function calculateApplicationAddress(
        IConsensus _consensus,
        IInputBox _inputBox,
        IInputRelay[] memory _inputRelays,
        address _appOwner,
        bytes32 _templateHash,
        bytes32 _salt
    ) external view override returns (address) {
        return
            Create2.computeAddress(
                _salt,
                keccak256(
                    abi.encodePacked(
                        type(Application).creationCode,
                        abi.encode(
                            _consensus,
                            _inputBox,
                            _inputRelays,
                            _appOwner,
                            _templateHash
                        )
                    )
                )
            );
    }
}
