// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Application Factory Test
pragma solidity ^0.8.22;

import {TestBase} from "../util/TestBase.sol";
import {ApplicationFactory, IApplicationFactory} from "contracts/dapp/ApplicationFactory.sol";
import {Application} from "contracts/dapp/Application.sol";
import {IConsensus} from "contracts/consensus/IConsensus.sol";
import {IInputBox} from "contracts/inputs/IInputBox.sol";
import {IPortal} from "contracts/portals/IPortal.sol";
import {Vm} from "forge-std/Vm.sol";

contract ApplicationFactoryTest is TestBase {
    ApplicationFactory _factory;

    function setUp() public {
        _factory = new ApplicationFactory();
    }

    function testNewApplication(
        IConsensus consensus,
        IInputBox inputBox,
        IPortal[] calldata portals,
        address appOwner,
        bytes32 templateHash
    ) public {
        vm.assume(appOwner != address(0));

        Application appContract = _factory.newApplication(
            consensus,
            inputBox,
            portals,
            appOwner,
            templateHash
        );

        assertEq(address(appContract.getConsensus()), address(consensus));
        assertEq(address(appContract.getInputBox()), address(inputBox));
        // abi.encode is used instead of a loop
        assertEq(abi.encode(appContract.getPortals()), abi.encode(portals));
        assertEq(appContract.owner(), appOwner);
        assertEq(appContract.getTemplateHash(), templateHash);
    }

    function testNewApplicationDeterministic(
        IConsensus consensus,
        IInputBox inputBox,
        IPortal[] calldata portals,
        address appOwner,
        bytes32 templateHash,
        bytes32 salt
    ) public {
        vm.assume(appOwner != address(0));

        address precalculatedAddress = _factory.calculateApplicationAddress(
            consensus,
            inputBox,
            portals,
            appOwner,
            templateHash,
            salt
        );

        Application appContract = _factory.newApplication(
            consensus,
            inputBox,
            portals,
            appOwner,
            templateHash,
            salt
        );

        // Precalculated address must match actual address
        assertEq(precalculatedAddress, address(appContract));

        assertEq(address(appContract.getConsensus()), address(consensus));
        assertEq(address(appContract.getInputBox()), address(inputBox));
        assertEq(abi.encode(appContract.getPortals()), abi.encode(portals));
        assertEq(appContract.owner(), appOwner);
        assertEq(appContract.getTemplateHash(), templateHash);

        precalculatedAddress = _factory.calculateApplicationAddress(
            consensus,
            inputBox,
            portals,
            appOwner,
            templateHash,
            salt
        );

        // Precalculated address must STILL match actual address
        assertEq(precalculatedAddress, address(appContract));

        // Cannot deploy an application with the same salt twice
        vm.expectRevert(bytes(""));
        _factory.newApplication(
            consensus,
            inputBox,
            portals,
            appOwner,
            templateHash,
            salt
        );
    }

    function testApplicationCreatedEvent(
        IConsensus consensus,
        IInputBox inputBox,
        IPortal[] calldata portals,
        address appOwner,
        bytes32 templateHash
    ) public {
        vm.assume(appOwner != address(0));

        vm.recordLogs();

        Application appContract = _factory.newApplication(
            consensus,
            inputBox,
            portals,
            appOwner,
            templateHash
        );

        _testApplicationCreatedEventAux(
            consensus,
            inputBox,
            portals,
            appOwner,
            templateHash,
            appContract
        );
    }

    function testApplicationCreatedEventDeterministic(
        IConsensus consensus,
        IInputBox inputBox,
        IPortal[] calldata portals,
        address appOwner,
        bytes32 templateHash,
        bytes32 salt
    ) public {
        vm.assume(appOwner != address(0));

        vm.recordLogs();

        Application appContract = _factory.newApplication(
            consensus,
            inputBox,
            portals,
            appOwner,
            templateHash,
            salt
        );

        _testApplicationCreatedEventAux(
            consensus,
            inputBox,
            portals,
            appOwner,
            templateHash,
            appContract
        );
    }

    function _testApplicationCreatedEventAux(
        IConsensus consensus,
        IInputBox inputBox,
        IPortal[] calldata portals,
        address appOwner,
        bytes32 templateHash,
        Application appContract
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
                    bytes32(uint256(uint160(address(consensus))))
                );

                (
                    IInputBox inputBox_,
                    IPortal[] memory portals_,
                    address appOwner_,
                    bytes32 templateHash_,
                    Application app_
                ) = abi.decode(
                        entry.data,
                        (IInputBox, IPortal[], address, bytes32, Application)
                    );

                assertEq(address(inputBox), address(inputBox_));
                assertEq(abi.encode(portals), abi.encode(portals_));
                assertEq(appOwner, appOwner_);
                assertEq(templateHash, templateHash_);
                assertEq(address(appContract), address(app_));
            }
        }

        assertEq(numOfApplicationsCreated, 1);
    }
}
