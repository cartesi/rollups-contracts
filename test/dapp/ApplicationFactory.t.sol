// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Application Factory Test
pragma solidity ^0.8.22;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {TestBase} from "../util/TestBase.sol";
import {ApplicationFactory, IApplicationFactory} from "contracts/dapp/ApplicationFactory.sol";
import {IApplication} from "contracts/dapp/IApplication.sol";
import {IConsensus} from "contracts/consensus/IConsensus.sol";
import {Vm} from "forge-std/Vm.sol";

contract ApplicationFactoryTest is TestBase {
    ApplicationFactory _factory;

    function setUp() public {
        _factory = new ApplicationFactory();
    }

    function testNewApplication(
        IConsensus consensus,
        address appOwner,
        bytes32 templateHash,
        IERC165 dataAvailability
    ) public {
        vm.assume(appOwner != address(0));

        IApplication appContract = _factory.newApplication(
            consensus,
            appOwner,
            templateHash,
            dataAvailability
        );

        assertEq(address(appContract.getConsensus()), address(consensus));
        assertEq(appContract.owner(), appOwner);
        assertEq(appContract.getTemplateHash(), templateHash);
        assertEq(address(appContract.getDataAvailability()), address(dataAvailability));
    }

    function testNewApplicationDeterministic(
        IConsensus consensus,
        address appOwner,
        bytes32 templateHash,
        IERC165 dataAvailability,
        bytes32 salt
    ) public {
        vm.assume(appOwner != address(0));

        address precalculatedAddress = _factory.calculateApplicationAddress(
            consensus,
            appOwner,
            templateHash,
            dataAvailability,
            salt
        );

        IApplication appContract = _factory.newApplication(
            consensus,
            appOwner,
            templateHash,
            dataAvailability,
            salt
        );

        // Precalculated address must match actual address
        assertEq(precalculatedAddress, address(appContract));

        assertEq(address(appContract.getConsensus()), address(consensus));
        assertEq(appContract.owner(), appOwner);
        assertEq(appContract.getTemplateHash(), templateHash);
        assertEq(address(appContract.getDataAvailability()), address(dataAvailability));

        precalculatedAddress = _factory.calculateApplicationAddress(
            consensus,
            appOwner,
            templateHash,
            dataAvailability,
            salt
        );

        // Precalculated address must STILL match actual address
        assertEq(precalculatedAddress, address(appContract));

        // Cannot deploy an application with the same salt twice
        vm.expectRevert(bytes(""));
        _factory.newApplication(
            consensus,
            appOwner,
            templateHash,
            dataAvailability,
            salt
        );
    }

    function testApplicationCreatedEvent(
        IConsensus consensus,
        address appOwner,
        bytes32 templateHash,
        IERC165 dataAvailability
    ) public {
        vm.assume(appOwner != address(0));

        vm.recordLogs();

        IApplication appContract = _factory.newApplication(
            consensus,
            appOwner,
            templateHash,
            dataAvailability
        );

        _testApplicationCreatedEventAux(
            consensus,
            appOwner,
            templateHash,
            dataAvailability,
            appContract
        );
    }

    function testApplicationCreatedEventDeterministic(
        IConsensus consensus,
        address appOwner,
        bytes32 templateHash,
        IERC165 dataAvailability,
        bytes32 salt
    ) public {
        vm.assume(appOwner != address(0));

        vm.recordLogs();

        IApplication appContract = _factory.newApplication(
            consensus,
            appOwner,
            templateHash,
            dataAvailability,
            salt
        );

        _testApplicationCreatedEventAux(
            consensus,
            appOwner,
            templateHash,
            dataAvailability,
            appContract
        );
    }

    function _testApplicationCreatedEventAux(
        IConsensus consensus,
        address appOwner,
        bytes32 templateHash,
        IERC165 dataAvailability,
        IApplication appContract
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
                    address appOwner_,
                    bytes32 templateHash_,
                    IERC165 dataAvailability_,
                    IApplication app_
                ) = abi.decode(
                        entry.data,
                        (address, bytes32, IERC165, IApplication)
                    );

                assertEq(appOwner, appOwner_);
                assertEq(templateHash, templateHash_);
                assertEq(address(dataAvailability), address(dataAvailability_));
                assertEq(address(appContract), address(app_));
            }
        }

        assertEq(numOfApplicationsCreated, 1);
    }
}
