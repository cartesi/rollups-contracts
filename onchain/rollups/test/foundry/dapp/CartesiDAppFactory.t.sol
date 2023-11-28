// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

/// @title Cartesi DApp Factory Test
pragma solidity ^0.8.8;

import {TestBase} from "../util/TestBase.sol";
import {SimpleConsensus} from "../util/SimpleConsensus.sol";
import {CartesiDAppFactory} from "contracts/dapp/CartesiDAppFactory.sol";
import {CartesiDApp} from "contracts/dapp/CartesiDApp.sol";
import {IConsensus} from "contracts/consensus/IConsensus.sol";
import {IInputBox} from "contracts/inputs/IInputBox.sol";
import {Vm} from "forge-std/Vm.sol";

contract CartesiDAppFactoryTest is TestBase {
    CartesiDAppFactory factory;
    IConsensus consensus;

    function setUp() public {
        factory = new CartesiDAppFactory();
        consensus = new SimpleConsensus();
    }

    event ApplicationCreated(
        IConsensus indexed consensus,
        IInputBox inputBox,
        address dappOwner,
        bytes32 templateHash,
        CartesiDApp application
    );

    struct ApplicationCreatedEventData {
        IInputBox inputBox;
        address dappOwner;
        bytes32 templateHash;
        CartesiDApp application;
    }

    function testNewApplication(
        IInputBox _inputBox,
        address _dappOwner,
        bytes32 _templateHash
    ) public {
        vm.assume(_dappOwner != address(0));

        CartesiDApp dapp = factory.newApplication(
            consensus,
            _inputBox,
            _dappOwner,
            _templateHash
        );

        assertEq(address(dapp.getConsensus()), address(consensus));
        assertEq(address(dapp.getInputBox()), address(_inputBox));
        assertEq(dapp.owner(), _dappOwner);
        assertEq(dapp.getTemplateHash(), _templateHash);
    }

    function testNewApplicationDeterministic(
        IInputBox _inputBox,
        address _dappOwner,
        bytes32 _templateHash,
        bytes32 _salt
    ) public {
        vm.assume(_dappOwner != address(0));

        address precalculatedAddress = factory.calculateApplicationAddress(
            consensus,
            _inputBox,
            _dappOwner,
            _templateHash,
            _salt
        );

        CartesiDApp dapp = factory.newApplication(
            consensus,
            _inputBox,
            _dappOwner,
            _templateHash,
            _salt
        );

        // Precalculated address must match actual address
        assertEq(precalculatedAddress, address(dapp));

        assertEq(address(dapp.getConsensus()), address(consensus));
        assertEq(address(dapp.getInputBox()), address(_inputBox));
        assertEq(dapp.owner(), _dappOwner);
        assertEq(dapp.getTemplateHash(), _templateHash);

        precalculatedAddress = factory.calculateApplicationAddress(
            consensus,
            _inputBox,
            _dappOwner,
            _templateHash,
            _salt
        );

        // Precalculated address must STILL match actual address
        assertEq(precalculatedAddress, address(dapp));

        // Cannot deploy a DApp with the same salt twice
        vm.expectRevert(bytes(""));
        factory.newApplication(
            consensus,
            _inputBox,
            _dappOwner,
            _templateHash,
            _salt
        );
    }

    function testApplicationCreatedEvent(
        IInputBox _inputBox,
        address _dappOwner,
        bytes32 _templateHash
    ) public {
        vm.assume(_dappOwner != address(0));

        // Start the recorder
        vm.recordLogs();

        // perform call and emit event
        // the first event is `OwnershipTransferred` emitted by Ownable constructor
        // the second event is `OwnershipTransferred` emitted by CartesiDApp constructor
        // the third event is `ApplicationCreated` emitted by `newApplication` function
        // we focus on the third event
        CartesiDApp dapp = factory.newApplication(
            consensus,
            _inputBox,
            _dappOwner,
            _templateHash
        );

        testApplicationCreatedEventAux(
            _inputBox,
            _dappOwner,
            _templateHash,
            dapp
        );
    }

    function testApplicationCreatedEventDeterministic(
        IInputBox _inputBox,
        address _dappOwner,
        bytes32 _templateHash,
        bytes32 _salt
    ) public {
        vm.assume(_dappOwner != address(0));

        // Start the recorder
        vm.recordLogs();

        // perform call and emit event
        // the first event is `OwnershipTransferred` emitted by Ownable constructor
        // the second event is `OwnershipTransferred` emitted by CartesiDApp constructor
        // the third event is `ApplicationCreated` emitted by `newApplication` function
        // we focus on the third event
        CartesiDApp dapp = factory.newApplication(
            consensus,
            _inputBox,
            _dappOwner,
            _templateHash,
            _salt
        );

        testApplicationCreatedEventAux(
            _inputBox,
            _dappOwner,
            _templateHash,
            dapp
        );
    }

    function testApplicationCreatedEventAux(
        IInputBox _inputBox,
        address _dappOwner,
        bytes32 _templateHash,
        CartesiDApp _dapp
    ) internal {
        Vm.Log[] memory entries = vm.getRecordedLogs();

        uint256 numOfApplicationsCreated;

        for (uint256 i; i < entries.length; ++i) {
            Vm.Log memory entry = entries[i];

            if (
                entry.emitter == address(factory) &&
                entry.topics[0] == ApplicationCreated.selector
            ) {
                ++numOfApplicationsCreated;

                assertEq(
                    entry.topics[1],
                    bytes32(uint256(uint160(address(consensus))))
                );

                ApplicationCreatedEventData memory eventData;

                eventData = abi.decode(
                    entry.data,
                    (ApplicationCreatedEventData)
                );

                assertEq(address(_inputBox), address(eventData.inputBox));
                assertEq(_dappOwner, eventData.dappOwner);
                assertEq(_templateHash, eventData.templateHash);
                assertEq(address(_dapp), address(eventData.application));
            }
        }

        assertEq(numOfApplicationsCreated, 1);
    }
}
