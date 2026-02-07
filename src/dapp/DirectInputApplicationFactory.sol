// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {Create2} from "@openzeppelin-contracts-5.2.0/utils/Create2.sol";

import {IApplicationFactory} from "./IApplicationFactory.sol";
import {IDirectInputApplicationFactory} from "./IDirectInputApplicationFactory.sol";
import {IOutputsMerkleRootValidator} from "../consensus/IOutputsMerkleRootValidator.sol";
import {Application} from "./Application.sol";
import {DataAvailability} from "../common/DataAvailability.sol";
import {IApplication} from "./IApplication.sol";
import {IInputBox} from "../inputs/IInputBox.sol";

/// @title Application Factory
/// @notice Allows anyone to reliably deploy a new `IApplication` contract.
contract DirectInputApplicationFactory is IDirectInputApplicationFactory {
    IApplicationFactory private immutable _applicationFactory;
    IInputBox private immutable _inputBox;

    constructor(IApplicationFactory applicationFactory, IInputBox inputBox) {
        _applicationFactory = applicationFactory;
        _inputBox = inputBox;
    }

    function newApplication(
        IOutputsMerkleRootValidator outputsMerkleRootValidator,
        address appOwner,
        bytes32 templateHash,
        bytes32 salt
    ) external override returns (IApplication) {
        bytes memory dataAvailability =
            abi.encodeCall(DataAvailability.InputBox, (_inputBox));
        return _applicationFactory.newApplication(
            outputsMerkleRootValidator, appOwner, templateHash, dataAvailability, salt
        );
    }

    function calculateApplicationAddress(
        IOutputsMerkleRootValidator outputsMerkleRootValidator,
        address appOwner,
        bytes32 templateHash,
        bytes32 salt
    ) external view override returns (address) {
        bytes memory dataAvailability =
            abi.encodeCall(DataAvailability.InputBox, (_inputBox));
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
