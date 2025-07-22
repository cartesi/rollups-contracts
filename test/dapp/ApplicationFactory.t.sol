// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Application Factory Test
pragma solidity ^0.8.22;

import {ApplicationFactory} from "src/dapp/ApplicationFactory.sol";
import {IApplicationFactory} from "src/dapp/IApplicationFactory.sol";
import {IApplication} from "src/dapp/IApplication.sol";
import {Application} from "src/dapp/Application.sol";
import {IOutputsMerkleRootValidator} from "src/consensus/IOutputsMerkleRootValidator.sol";

import {Test} from "forge-std-1.9.6/src/Test.sol";
import {Vm} from "forge-std-1.9.6/src/Vm.sol";

import {Errors} from "@openzeppelin-contracts-5.2.0/utils/Errors.sol";

contract ApplicationFactoryTest is Test {
    ApplicationFactory _factory;

    function setUp() public {
        _factory = new ApplicationFactory(new Application());
    }

    function testNewApplication(
        uint256 blockNumber,
        IOutputsMerkleRootValidator outputsMerkleRootValidator,
        address appOwner,
        bytes32 templateHash,
        bytes calldata dataAvailability
    ) public {
        vm.assume(appOwner != address(0));

        vm.roll(blockNumber);

        IApplication appContract = _factory.newApplication(
            outputsMerkleRootValidator, appOwner, templateHash, dataAvailability
        );

        assertEq(
            address(appContract.getOutputsMerkleRootValidator()),
            address(outputsMerkleRootValidator)
        );
        assertEq(appContract.owner(), appOwner);
        assertEq(appContract.getTemplateHash(), templateHash);
        assertEq(appContract.getDataAvailability(), dataAvailability);
        assertEq(appContract.getDeploymentBlockNumber(), blockNumber);
    }

    function testNewApplicationDeterministic(
        uint256 blockNumber,
        IOutputsMerkleRootValidator outputsMerkleRootValidator,
        address appOwner,
        bytes32 templateHash,
        bytes calldata dataAvailability,
        bytes32 salt
    ) public {
        vm.assume(appOwner != address(0));

        vm.roll(blockNumber);

        address precalculatedAddress = _factory.calculateApplicationAddress(
            outputsMerkleRootValidator, appOwner, templateHash, dataAvailability, salt
        );

        IApplication appContract = _factory.newApplication(
            outputsMerkleRootValidator, appOwner, templateHash, dataAvailability, salt
        );

        // Precalculated address must match actual address
        assertEq(precalculatedAddress, address(appContract));

        assertEq(
            address(appContract.getOutputsMerkleRootValidator()),
            address(outputsMerkleRootValidator)
        );
        assertEq(appContract.owner(), appOwner);
        assertEq(appContract.getTemplateHash(), templateHash);
        assertEq(appContract.getDataAvailability(), dataAvailability);
        assertEq(appContract.getDeploymentBlockNumber(), blockNumber);

        precalculatedAddress = _factory.calculateApplicationAddress(
            outputsMerkleRootValidator, appOwner, templateHash, dataAvailability, salt
        );

        // Precalculated address must STILL match actual address
        assertEq(precalculatedAddress, address(appContract));

        // Cannot deploy an application with the same salt twice
        vm.expectRevert(Errors.FailedDeployment.selector);
        _factory.newApplication(
            outputsMerkleRootValidator, appOwner, templateHash, dataAvailability, salt
        );
    }

    function testApplicationCreatedEvent(
        IOutputsMerkleRootValidator outputsMerkleRootValidator,
        address appOwner,
        bytes32 templateHash,
        bytes calldata dataAvailability
    ) public {
        vm.assume(appOwner != address(0));

        vm.recordLogs();

        IApplication appContract = _factory.newApplication(
            outputsMerkleRootValidator, appOwner, templateHash, dataAvailability
        );

        _testApplicationCreatedEventAux(
            outputsMerkleRootValidator,
            appOwner,
            templateHash,
            dataAvailability,
            appContract
        );
    }

    function testApplicationCreatedEventDeterministic(
        IOutputsMerkleRootValidator outputsMerkleRootValidator,
        address appOwner,
        bytes32 templateHash,
        bytes calldata dataAvailability,
        bytes32 salt
    ) public {
        vm.assume(appOwner != address(0));

        vm.recordLogs();

        IApplication appContract = _factory.newApplication(
            outputsMerkleRootValidator, appOwner, templateHash, dataAvailability, salt
        );

        _testApplicationCreatedEventAux(
            outputsMerkleRootValidator,
            appOwner,
            templateHash,
            dataAvailability,
            appContract
        );
    }

    function _testApplicationCreatedEventAux(
        IOutputsMerkleRootValidator outputsMerkleRootValidator,
        address appOwner,
        bytes32 templateHash,
        bytes calldata dataAvailability,
        IApplication appContract
    ) internal {
        Vm.Log[] memory entries = vm.getRecordedLogs();

        uint256 numOfApplicationsCreated;

        for (uint256 i; i < entries.length; ++i) {
            Vm.Log memory entry = entries[i];

            if (
                entry.emitter == address(_factory)
                    && entry.topics[0] == IApplicationFactory.ApplicationCreated.selector
            ) {
                ++numOfApplicationsCreated;

                assertEq(
                    entry.topics[1],
                    bytes32(uint256(uint160(address(outputsMerkleRootValidator))))
                );

                (
                    address appOwner_,
                    bytes32 templateHash_,
                    bytes memory dataAvailability_,
                    IApplication app_
                ) = abi.decode(entry.data, (address, bytes32, bytes, IApplication));

                assertEq(appOwner, appOwner_);
                assertEq(templateHash, templateHash_);
                assertEq(dataAvailability, dataAvailability_);
                assertEq(address(appContract), address(app_));
            }
        }

        assertEq(numOfApplicationsCreated, 1);
    }
}
