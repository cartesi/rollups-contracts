// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Application Factory Test
pragma solidity ^0.8.22;

import {TestBase} from "../util/TestBase.sol";
import {SimpleConsensus} from "../util/SimpleConsensus.sol";
import {ApplicationFactory, IApplicationFactory} from "contracts/dapp/ApplicationFactory.sol";
import {Application} from "contracts/dapp/Application.sol";
import {IConsensus} from "contracts/consensus/IConsensus.sol";
import {IInputBox} from "contracts/inputs/IInputBox.sol";
import {IInputRelay} from "contracts/inputs/IInputRelay.sol";
import {Vm} from "forge-std/Vm.sol";

contract ApplicationFactoryTest is TestBase {
    ApplicationFactory _factory;
    IConsensus _consensus;

    function setUp() public {
        _factory = new ApplicationFactory();
        _consensus = new SimpleConsensus();
    }

    function testNewApplication(
        IInputBox inputBox,
        IInputRelay[] calldata inputRelays,
        address appOwner,
        bytes32 templateHash
    ) public {
        vm.assume(appOwner != address(0));

        Application app = _factory.newApplication(
            _consensus,
            inputBox,
            inputRelays,
            appOwner,
            templateHash
        );

        assertEq(address(app.getConsensus()), address(_consensus));
        assertEq(address(app.getInputBox()), address(inputBox));
        // abi.encode is used instead of a loop
        assertEq(abi.encode(app.getInputRelays()), abi.encode(inputRelays));
        assertEq(app.owner(), appOwner);
        assertEq(app.getTemplateHash(), templateHash);
    }

    function testNewApplicationDeterministic(
        IInputBox inputBox,
        IInputRelay[] calldata inputRelays,
        address appOwner,
        bytes32 templateHash,
        bytes32 salt
    ) public {
        vm.assume(appOwner != address(0));

        address precalculatedAddress = _factory.calculateApplicationAddress(
            _consensus,
            inputBox,
            inputRelays,
            appOwner,
            templateHash,
            salt
        );

        Application app = _factory.newApplication(
            _consensus,
            inputBox,
            inputRelays,
            appOwner,
            templateHash,
            salt
        );

        // Precalculated address must match actual address
        assertEq(precalculatedAddress, address(app));

        assertEq(address(app.getConsensus()), address(_consensus));
        assertEq(address(app.getInputBox()), address(inputBox));
        assertEq(abi.encode(app.getInputRelays()), abi.encode(inputRelays));
        assertEq(app.owner(), appOwner);
        assertEq(app.getTemplateHash(), templateHash);

        precalculatedAddress = _factory.calculateApplicationAddress(
            _consensus,
            inputBox,
            inputRelays,
            appOwner,
            templateHash,
            salt
        );

        // Precalculated address must STILL match actual address
        assertEq(precalculatedAddress, address(app));

        // Cannot deploy an application with the same salt twice
        vm.expectRevert(bytes(""));
        _factory.newApplication(
            _consensus,
            inputBox,
            inputRelays,
            appOwner,
            templateHash,
            salt
        );
    }

    function testApplicationCreatedEvent(
        IInputBox inputBox,
        IInputRelay[] calldata inputRelays,
        address appOwner,
        bytes32 templateHash
    ) public {
        vm.assume(appOwner != address(0));

        vm.recordLogs();

        Application app = _factory.newApplication(
            _consensus,
            inputBox,
            inputRelays,
            appOwner,
            templateHash
        );

        _testApplicationCreatedEventAux(
            inputBox,
            inputRelays,
            appOwner,
            templateHash,
            app
        );
    }

    function testApplicationCreatedEventDeterministic(
        IInputBox inputBox,
        IInputRelay[] calldata inputRelays,
        address appOwner,
        bytes32 templateHash,
        bytes32 salt
    ) public {
        vm.assume(appOwner != address(0));

        vm.recordLogs();

        Application app = _factory.newApplication(
            _consensus,
            inputBox,
            inputRelays,
            appOwner,
            templateHash,
            salt
        );

        _testApplicationCreatedEventAux(
            inputBox,
            inputRelays,
            appOwner,
            templateHash,
            app
        );
    }

    function _testApplicationCreatedEventAux(
        IInputBox inputBox,
        IInputRelay[] calldata inputRelays,
        address appOwner,
        bytes32 templateHash,
        Application app
    ) internal {
        Vm.Log[] memory entries = vm.getRecordedLogs();

        uint256 numOfApplicationsCreated;

        for (uint256 i; i < entries.length; ++i) {
            Vm.Log memory entry = entries[i];

            if (
                entry.emitter == address(_factory) &&
                entry.topics[0] ==
                IApplicationFactory.ApplicationCreated.selector
            ) {
                ++numOfApplicationsCreated;

                assertEq(
                    entry.topics[1],
                    bytes32(uint256(uint160(address(_consensus))))
                );

                (
                    IInputBox inputBox_,
                    IInputRelay[] memory inputRelays_,
                    address appOwner_,
                    bytes32 templateHash_,
                    Application app_
                ) = abi.decode(
                        entry.data,
                        (
                            IInputBox,
                            IInputRelay[],
                            address,
                            bytes32,
                            Application
                        )
                    );

                assertEq(address(inputBox), address(inputBox_));
                assertEq(abi.encode(inputRelays), abi.encode(inputRelays_));
                assertEq(appOwner, appOwner_);
                assertEq(templateHash, templateHash_);
                assertEq(address(app), address(app_));
            }
        }

        assertEq(numOfApplicationsCreated, 1);
    }
}
