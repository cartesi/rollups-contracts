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
    ApplicationFactory factory;
    IConsensus consensus;

    function setUp() public {
        factory = new ApplicationFactory();
        consensus = new SimpleConsensus();
    }

    function testNewApplication(
        IInputBox _inputBox,
        IInputRelay[] calldata _inputRelays,
        address _appOwner,
        bytes32 _templateHash
    ) public {
        vm.assume(_appOwner != address(0));

        Application app = factory.newApplication(
            consensus,
            _inputBox,
            _inputRelays,
            _appOwner,
            _templateHash
        );

        assertEq(address(app.getConsensus()), address(consensus));
        assertEq(address(app.getInputBox()), address(_inputBox));
        // abi.encode is used instead of a loop
        assertEq(abi.encode(app.getInputRelays()), abi.encode(_inputRelays));
        assertEq(app.owner(), _appOwner);
        assertEq(app.getTemplateHash(), _templateHash);
    }

    function testNewApplicationDeterministic(
        IInputBox _inputBox,
        IInputRelay[] calldata _inputRelays,
        address _appOwner,
        bytes32 _templateHash,
        bytes32 _salt
    ) public {
        vm.assume(_appOwner != address(0));

        address precalculatedAddress = factory.calculateApplicationAddress(
            consensus,
            _inputBox,
            _inputRelays,
            _appOwner,
            _templateHash,
            _salt
        );

        Application app = factory.newApplication(
            consensus,
            _inputBox,
            _inputRelays,
            _appOwner,
            _templateHash,
            _salt
        );

        // Precalculated address must match actual address
        assertEq(precalculatedAddress, address(app));

        assertEq(address(app.getConsensus()), address(consensus));
        assertEq(address(app.getInputBox()), address(_inputBox));
        assertEq(abi.encode(app.getInputRelays()), abi.encode(_inputRelays));
        assertEq(app.owner(), _appOwner);
        assertEq(app.getTemplateHash(), _templateHash);

        precalculatedAddress = factory.calculateApplicationAddress(
            consensus,
            _inputBox,
            _inputRelays,
            _appOwner,
            _templateHash,
            _salt
        );

        // Precalculated address must STILL match actual address
        assertEq(precalculatedAddress, address(app));

        // Cannot deploy an application with the same salt twice
        vm.expectRevert(bytes(""));
        factory.newApplication(
            consensus,
            _inputBox,
            _inputRelays,
            _appOwner,
            _templateHash,
            _salt
        );
    }

    function testApplicationCreatedEvent(
        IInputBox _inputBox,
        IInputRelay[] calldata _inputRelays,
        address _appOwner,
        bytes32 _templateHash
    ) public {
        vm.assume(_appOwner != address(0));

        vm.recordLogs();

        Application app = factory.newApplication(
            consensus,
            _inputBox,
            _inputRelays,
            _appOwner,
            _templateHash
        );

        testApplicationCreatedEventAux(
            _inputBox,
            _inputRelays,
            _appOwner,
            _templateHash,
            app
        );
    }

    function testApplicationCreatedEventDeterministic(
        IInputBox _inputBox,
        IInputRelay[] calldata _inputRelays,
        address _appOwner,
        bytes32 _templateHash,
        bytes32 _salt
    ) public {
        vm.assume(_appOwner != address(0));

        vm.recordLogs();

        Application app = factory.newApplication(
            consensus,
            _inputBox,
            _inputRelays,
            _appOwner,
            _templateHash,
            _salt
        );

        testApplicationCreatedEventAux(
            _inputBox,
            _inputRelays,
            _appOwner,
            _templateHash,
            app
        );
    }

    function testApplicationCreatedEventAux(
        IInputBox _inputBox,
        IInputRelay[] calldata _inputRelays,
        address _appOwner,
        bytes32 _templateHash,
        Application _app
    ) internal {
        Vm.Log[] memory entries = vm.getRecordedLogs();

        uint256 numOfApplicationsCreated;

        for (uint256 i; i < entries.length; ++i) {
            Vm.Log memory entry = entries[i];

            if (
                entry.emitter == address(factory) &&
                entry.topics[0] ==
                IApplicationFactory.ApplicationCreated.selector
            ) {
                ++numOfApplicationsCreated;

                assertEq(
                    entry.topics[1],
                    bytes32(uint256(uint160(address(consensus))))
                );

                (
                    IInputBox inputBox,
                    IInputRelay[] memory inputRelays,
                    address appOwner,
                    bytes32 templateHash,
                    Application app
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

                assertEq(address(_inputBox), address(inputBox));
                assertEq(abi.encode(_inputRelays), abi.encode(inputRelays));
                assertEq(_appOwner, appOwner);
                assertEq(_templateHash, templateHash);
                assertEq(address(_app), address(app));
            }
        }

        assertEq(numOfApplicationsCreated, 1);
    }
}
