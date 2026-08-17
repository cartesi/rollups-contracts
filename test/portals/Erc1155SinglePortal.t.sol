// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {IERC1155} from "@openzeppelin-contracts-5.2.0/token/ERC1155/IERC1155.sol";
import {IERC1155Receiver} from "@openzeppelin-contracts-5.2.0/token/ERC1155/IERC1155Receiver.sol";

import {Vm} from "forge-std-1.9.6/src/Vm.sol";

import {IInputBox} from "../../src/inputs/IInputBox.sol";
import {IErc1155SinglePortal} from "../../src/portals/IErc1155SinglePortal.sol";

import {InputBoxTestUtils} from "../util/InputBoxTestUtils.sol";
import {LibBytes} from "../util/LibBytes.sol";
import {LibTopic} from "../util/LibTopic.sol";
import {RollupsTest} from "../util/RollupsTest.sol";
import {VersionGetterTestUtils} from "../util/VersionGetterTestUtils.sol";

contract Erc1155SinglePortalTest is
    RollupsTest,
    InputBoxTestUtils,
    VersionGetterTestUtils
{
    using LibTopic for address;
    using LibBytes for bytes;

    IInputBox _inputBox;
    IErc1155SinglePortal _portal;

    function setUp() public {
        _inputBox = _contracts.core.inputBox;
        _portal = _contracts.core.erc1155SinglePortal;
    }

    function testVersion() external view {
        _testVersion(_portal);
    }

    function testDepositRevertApplicationNotDeployed(
        uint256 tokenId,
        uint256 value,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external {
        address sender = _randomAccountWithNoCode();
        address appContract = _randomAccountWithNoCode();

        IERC1155 token = _randomSetup(sender, tokenId, value);

        vm.prank(sender);
        vm.expectRevert(_encodeApplicationNotDeployed(appContract));
        _portal.depositSingleErc1155Token(
            token, appContract, tokenId, value, baseLayerData, execLayerData
        );
    }

    function testDepositRevertApplicationReverted(
        uint256 tokenId,
        uint256 value,
        bytes calldata baseLayerData,
        bytes calldata execLayerData,
        bytes calldata errorData
    ) external {
        address sender = _randomAccountWithNoCode();
        address appContract = vm.randomBool()
            ? _newAppMockGetInputBoxReverts(errorData)
            : _newAppMockIsForeclosedReverts(errorData);

        IERC1155 token = _randomSetup(sender, tokenId, value);

        _mockOnErc1155Received(appContract, sender, tokenId, value, baseLayerData);

        vm.prank(sender);
        vm.expectRevert(_encodeApplicationReverted(appContract, errorData));
        _portal.depositSingleErc1155Token(
            token, appContract, tokenId, value, baseLayerData, execLayerData
        );
    }

    function testDepositRevertIllformedApplicationReturnDataSize(
        uint256 tokenId,
        uint256 value,
        bytes calldata baseLayerData,
        bytes calldata execLayerData,
        bytes calldata returnData
    ) external {
        vm.assume(returnData.length != 32);

        address sender = _randomAccountWithNoCode();
        address appContract = vm.randomBool()
            ? _newAppMockGetInputBoxReturns(returnData)
            : _newAppMockIsForeclosedReturns(returnData);

        IERC1155 token = _randomSetup(sender, tokenId, value);

        _mockOnErc1155Received(appContract, sender, tokenId, value, baseLayerData);

        vm.prank(sender);
        vm.expectRevert(_encodeIllformedApplicationReturnData(appContract, returnData));
        _portal.depositSingleErc1155Token(
            token, appContract, tokenId, value, baseLayerData, execLayerData
        );
    }

    function testDepositRevertIllformedApplicationReturnData(
        uint256 tokenId,
        uint256 value,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external {
        address sender = _randomAccountWithNoCode();
        (address appContract, bytes memory returnData) = vm.randomBool()
            ? _newAppMockGetInputBoxReturnsRandomIllformedData()
            : _newAppMockIsForeclosedReturnsRandomIllformedData();

        IERC1155 token = _randomSetup(sender, tokenId, value);

        _mockOnErc1155Received(appContract, sender, tokenId, value, baseLayerData);

        vm.prank(sender);
        vm.expectRevert(_encodeIllformedApplicationReturnData(appContract, returnData));
        _portal.depositSingleErc1155Token(
            token, appContract, tokenId, value, baseLayerData, execLayerData
        );
    }

    function testDepositRevertInputBoxNotDeployed(
        uint256 tokenId,
        uint256 value,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external {
        address sender = _randomAccountWithNoCode();
        address inputBox = _randomAccountWithNoCode();
        address appContract = _newAppMockGetInputBoxReturns(inputBox);

        IERC1155 token = _randomSetup(sender, tokenId, value);

        _mockOnErc1155Received(appContract, sender, tokenId, value, baseLayerData);

        vm.prank(sender);
        vm.expectRevert(_encodeInputBoxNotDeployed(inputBox));
        _portal.depositSingleErc1155Token(
            token, appContract, tokenId, value, baseLayerData, execLayerData
        );
    }

    function testDepositRevertApplicationForeclosed(
        uint256 tokenId,
        uint256 value,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external {
        address sender = _randomAccountWithNoCode();
        address appContract = _newForeclosedAppMock();

        IERC1155 token = _randomSetup(sender, tokenId, value);

        _mockOnErc1155Received(appContract, sender, tokenId, value, baseLayerData);

        vm.prank(sender);
        vm.expectRevert(_encodeApplicationForeclosed(appContract));
        _portal.depositSingleErc1155Token(
            token, appContract, tokenId, value, baseLayerData, execLayerData
        );
    }

    function testDeposit(
        uint256 tokenId,
        uint256 value,
        bytes calldata baseLayerData,
        bytes calldata execLayerData,
        bytes[] calldata payloads
    ) external {
        address sender = _randomAccountWithNoCode();
        address appContract = _newActiveAppMock();

        IERC1155 token = _randomSetup(sender, tokenId, value);

        _mockOnErc1155Received(appContract, sender, tokenId, value, baseLayerData);

        _addInputs(_inputBox, appContract, payloads);

        uint256 senderBalance = token.balanceOf(sender, tokenId);
        uint256 appContractBalance = token.balanceOf(appContract, tokenId);

        uint256 numOfInputs = _inputBox.getNumberOfInputs(appContract);

        vm.recordLogs();

        vm.prank(sender);
        _portal.depositSingleErc1155Token(
            token, appContract, tokenId, value, baseLayerData, execLayerData
        );

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes memory input;
        bytes memory payload;
        uint256 numOfInputAdded;
        uint256 numOfTransferSingle;

        for (uint256 i; i < logs.length; ++i) {
            Vm.Log memory log = logs[i];
            if (log.emitter == address(_inputBox)) {
                (input, payload) =
                    _decodeInputAdded(log, appContract, address(_portal), numOfInputs);
                ++numOfInputAdded;
            } else if (log.emitter == address(token)) {
                bytes32 topic0 = log.topics[0];
                if (topic0 == IERC1155.TransferSingle.selector) {
                    (uint256 arg1, uint256 arg2) =
                        abi.decode(log.data, (uint256, uint256));
                    assertEq(log.topics[1], address(_portal).asTopic());
                    assertEq(log.topics[2], sender.asTopic());
                    assertEq(log.topics[3], appContract.asTopic());
                    assertEq(arg1, tokenId);
                    assertEq(arg2, value);
                    ++numOfTransferSingle;
                } else {
                    revert UnexpectedLog(log);
                }
            } else {
                revert UnexpectedLog(log);
            }
        }

        assertEq(numOfInputAdded, 1);
        assertEq(numOfTransferSingle, 1);

        assertEq(token.balanceOf(sender, tokenId), senderBalance - value);
        assertEq(token.balanceOf(appContract, tokenId), appContractBalance + value);

        assertEq(_inputBox.getNumberOfInputs(appContract), numOfInputs + 1);
        assertEq(keccak256(input), _inputBox.getInputHash(appContract, numOfInputs));

        bytes memory buffer = payload;
        address tokenArg;
        address senderArg;
        uint256 tokenIdArg;
        uint256 valueArg;
        bytes memory baseLayerDataArg;
        bytes memory execLayerDataArg;

        (tokenArg, buffer) = buffer.consumeAddress();
        (senderArg, buffer) = buffer.consumeAddress();
        (tokenIdArg, buffer) = buffer.consumeUint256();
        (valueArg, buffer) = buffer.consumeUint256();
        (baseLayerDataArg, execLayerDataArg) = abi.decode(buffer, (bytes, bytes));

        assertEq(tokenArg, address(token));
        assertEq(senderArg, sender);
        assertEq(tokenIdArg, tokenId);
        assertEq(valueArg, value);
        assertEq(baseLayerDataArg, baseLayerData);
        assertEq(execLayerDataArg, execLayerData);
    }

    function _randomSetup(address sender, uint256 tokenId, uint256 value)
        internal
        returns (IERC1155 token)
    {
        // Get the pre-deployed ERC-1155 token contract
        token = _contracts.dev.testMultiToken;

        // Make the sender mint the tokens
        vm.prank(sender);
        _contracts.dev.testMultiToken.mint(tokenId, value);

        // Mine a random number of blocks
        vm.roll(vm.randomUint(vm.getBlockNumber(), type(uint256).max));

        // Make the sender give approval to the portal
        vm.prank(sender);
        token.setApprovalForAll(address(_portal), true);
    }

    function _mockOnErc1155Received(
        address appContract,
        address sender,
        uint256 tokenId,
        uint256 value,
        bytes memory baseLayerData
    ) internal {
        vm.mockCall(
            appContract,
            abi.encodeCall(
                IERC1155Receiver.onERC1155Received,
                (address(_portal), sender, tokenId, value, baseLayerData)
            ),
            abi.encode(IERC1155Receiver.onERC1155Received.selector)
        );
    }
}
