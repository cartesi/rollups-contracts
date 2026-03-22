// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {IERC1155} from "@openzeppelin-contracts-5.2.0/token/ERC1155/IERC1155.sol";
import {
    IERC1155Receiver
} from "@openzeppelin-contracts-5.2.0/token/ERC1155/IERC1155Receiver.sol";

import {Test} from "forge-std-1.9.6/src/Test.sol";
import {Vm} from "forge-std-1.9.6/src/Vm.sol";

import {IInputBox} from "src/inputs/IInputBox.sol";
import {InputBox} from "src/inputs/InputBox.sol";
import {ERC1155BatchPortal} from "src/portals/ERC1155BatchPortal.sol";
import {IERC1155BatchPortal} from "src/portals/IERC1155BatchPortal.sol";

import {InputBoxTestUtils} from "../util/InputBoxTestUtils.sol";
import {LibAddressArray} from "../util/LibAddressArray.sol";
import {LibBytes} from "../util/LibBytes.sol";
import {LibTopic} from "../util/LibTopic.sol";
import {LibUint256Array} from "../util/LibUint256Array.sol";
import {SimpleBatchERC1155} from "../util/SimpleERC1155.sol";
import {VersionGetterTestUtils} from "../util/VersionGetterTestUtils.sol";

contract ERC1155BatchPortalTest is Test, InputBoxTestUtils, VersionGetterTestUtils {
    using LibUint256Array for uint256[];
    using LibAddressArray for address;
    using LibUint256Array for Vm;
    using LibTopic for address;
    using LibBytes for bytes;

    IInputBox _inputBox;
    IERC1155BatchPortal _portal;

    function setUp() public {
        _inputBox = new InputBox();
        _portal = new ERC1155BatchPortal(_inputBox);
    }

    function testVersion() external view {
        _testVersion(_portal);
    }

    function testGetInputBox() public view {
        assertEq(address(_portal.getInputBox()), address(_inputBox));
    }

    function testDepositRevertApplicationNotDeployed(
        uint256[] calldata values,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external {
        address sender = _randomAccountWithNoCode();
        address appContract = _randomAccountWithNoCode();

        (IERC1155 token, uint256[] memory tokenIds) = _randomSetup(sender, values);

        vm.prank(sender);
        vm.expectRevert(_encodeApplicationNotDeployed(appContract));
        _portal.depositBatchERC1155Token(
            token, appContract, tokenIds, values, baseLayerData, execLayerData
        );
    }

    function testDepositRevertApplicationReverted(
        uint256[] calldata values,
        bytes calldata baseLayerData,
        bytes calldata execLayerData,
        bytes calldata error
    ) external {
        address sender = _randomAccountWithNoCode();
        address appContract = _newAppMockReverts(error);

        (IERC1155 token, uint256[] memory tokenIds) = _randomSetup(sender, values);

        _mockOnErc1155BatchReceived(appContract, sender, tokenIds, values, baseLayerData);

        vm.prank(sender);
        vm.expectRevert(_encodeApplicationReverted(appContract, error));
        _portal.depositBatchERC1155Token(
            token, appContract, tokenIds, values, baseLayerData, execLayerData
        );
    }

    function testDepositRevertIllformedApplicationReturnDataSize(
        uint256[] calldata values,
        bytes calldata baseLayerData,
        bytes calldata execLayerData,
        bytes calldata returnData
    ) external {
        vm.assume(returnData.length != 32);

        address sender = _randomAccountWithNoCode();
        address appContract = _newAppMockReturns(returnData);

        (IERC1155 token, uint256[] memory tokenIds) = _randomSetup(sender, values);

        _mockOnErc1155BatchReceived(appContract, sender, tokenIds, values, baseLayerData);

        vm.prank(sender);
        vm.expectRevert(_encodeIllformedApplicationReturnData(appContract, returnData));
        _portal.depositBatchERC1155Token(
            token, appContract, tokenIds, values, baseLayerData, execLayerData
        );
    }

    function testDepositRevertIllformedApplicationReturnDataInvalidBool(
        uint256[] calldata values,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external {
        uint256 returnValue = vm.randomUint(2, type(uint256).max);
        bytes memory returnData = abi.encode(returnValue);

        address sender = _randomAccountWithNoCode();
        address appContract = _newAppMockReturns(returnData);

        (IERC1155 token, uint256[] memory tokenIds) = _randomSetup(sender, values);

        _mockOnErc1155BatchReceived(appContract, sender, tokenIds, values, baseLayerData);

        vm.prank(sender);
        vm.expectRevert(_encodeIllformedApplicationReturnData(appContract, returnData));
        _portal.depositBatchERC1155Token(
            token, appContract, tokenIds, values, baseLayerData, execLayerData
        );
    }

    function testDepositRevertApplicationForeclosed(
        uint256[] calldata values,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external {
        address sender = _randomAccountWithNoCode();
        address appContract = _newForeclosedAppMock();

        (IERC1155 token, uint256[] memory tokenIds) = _randomSetup(sender, values);

        _mockOnErc1155BatchReceived(appContract, sender, tokenIds, values, baseLayerData);

        vm.prank(sender);
        vm.expectRevert(_encodeApplicationForeclosed(appContract));
        _portal.depositBatchERC1155Token(
            token, appContract, tokenIds, values, baseLayerData, execLayerData
        );
    }

    function testDeposit(
        uint256[] calldata values,
        bytes calldata baseLayerData,
        bytes calldata execLayerData,
        bytes[] calldata payloads
    ) external {
        address sender = _randomAccountWithNoCode();
        address appContract = _newActiveAppMock();

        (IERC1155 token, uint256[] memory tokenIds) = _randomSetup(sender, values);

        _mockOnErc1155BatchReceived(appContract, sender, tokenIds, values, baseLayerData);

        _addInputs(_inputBox, appContract, payloads);

        uint256[] memory senderBalances =
            token.balanceOfBatch(sender.repeat(tokenIds.length), tokenIds);
        uint256[] memory appContractBalances =
            token.balanceOfBatch(appContract.repeat(tokenIds.length), tokenIds);

        uint256 numOfInputs = _inputBox.getNumberOfInputs(appContract);

        vm.recordLogs();

        vm.prank(sender);
        _portal.depositBatchERC1155Token(
            token, appContract, tokenIds, values, baseLayerData, execLayerData
        );

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes memory input;
        bytes memory payload;
        uint256 numOfInputAdded;
        uint256 numOfTransferSingle;
        uint256 numOfTransferBatch;

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
                    assertEq(tokenIds.length, 1);
                    assertEq(arg1, tokenIds[0]);
                    assertEq(values.length, 1);
                    assertEq(arg2, values[0]);
                    ++numOfTransferSingle;
                } else if (topic0 == IERC1155.TransferBatch.selector) {
                    (uint256[] memory arg1, uint256[] memory arg2) =
                        abi.decode(log.data, (uint256[], uint256[]));
                    assertEq(log.topics[1], address(_portal).asTopic());
                    assertEq(log.topics[2], sender.asTopic());
                    assertEq(log.topics[3], appContract.asTopic());
                    assertEq(arg1, tokenIds);
                    assertEq(arg2, values);
                    ++numOfTransferBatch;
                } else {
                    revert("unexpected token contract topic #0");
                }
            } else {
                revert("unexpected log emitter");
            }
        }

        assertEq(numOfInputAdded, 1);

        if (tokenIds.length == 1) {
            assertEq(numOfTransferSingle, 1);
            assertEq(numOfTransferBatch, 0);
        } else {
            assertEq(numOfTransferSingle, 0);
            assertEq(numOfTransferBatch, 1);
        }

        assertEq(
            token.balanceOfBatch(sender.repeat(tokenIds.length), tokenIds),
            senderBalances.sub(values)
        );
        assertEq(
            token.balanceOfBatch(appContract.repeat(tokenIds.length), tokenIds),
            appContractBalances.add(values)
        );

        assertEq(_inputBox.getNumberOfInputs(appContract), numOfInputs + 1);
        assertEq(keccak256(input), _inputBox.getInputHash(appContract, numOfInputs));

        bytes memory buffer = payload;
        address tokenArg;
        address senderArg;
        uint256[] memory tokenIdsArg;
        uint256[] memory valuesArg;
        bytes memory baseLayerDataArg;
        bytes memory execLayerDataArg;

        (tokenArg, buffer) = buffer.consumeAddress();
        (senderArg, buffer) = buffer.consumeAddress();
        (tokenIdsArg, valuesArg, baseLayerDataArg, execLayerDataArg) =
            abi.decode(buffer, (uint256[], uint256[], bytes, bytes));

        assertEq(tokenArg, address(token));
        assertEq(senderArg, sender);
        assertEq(tokenIdsArg, tokenIds);
        assertEq(valuesArg, values);
        assertEq(baseLayerDataArg, baseLayerData);
        assertEq(execLayerDataArg, execLayerData);
    }

    function _randomSetup(address sender, uint256[] calldata values)
        internal
        returns (IERC1155 token, uint256[] memory tokenIds)
    {
        // Generate an array of unique uint256 values with the same size as `values`.
        tokenIds = vm.randomUniqueUint256Array(values.length);

        // Deploy the ERC-1155 token contract with the sender's tokens pre-minted
        token = new SimpleBatchERC1155(sender, tokenIds, values);

        // Mine a random number of blocks
        vm.roll(vm.randomUint(vm.getBlockNumber(), type(uint256).max));

        // Make the sender give approval to the portal
        vm.prank(sender);
        token.setApprovalForAll(address(_portal), true);
    }

    function _mockOnErc1155BatchReceived(
        address appContract,
        address sender,
        uint256[] memory tokenIds,
        uint256[] memory values,
        bytes memory baseLayerData
    ) internal {
        if (tokenIds.length == 1) {
            vm.mockCall(
                appContract,
                abi.encodeCall(
                    IERC1155Receiver.onERC1155Received,
                    (address(_portal), sender, tokenIds[0], values[0], baseLayerData)
                ),
                abi.encode(IERC1155Receiver.onERC1155Received.selector)
            );
        } else {
            vm.mockCall(
                appContract,
                abi.encodeCall(
                    IERC1155Receiver.onERC1155BatchReceived,
                    (address(_portal), sender, tokenIds, values, baseLayerData)
                ),
                abi.encode(IERC1155Receiver.onERC1155BatchReceived.selector)
            );
        }
    }
}
