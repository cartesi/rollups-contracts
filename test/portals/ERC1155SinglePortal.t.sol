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
import {ERC1155SinglePortal} from "src/portals/ERC1155SinglePortal.sol";
import {IERC1155SinglePortal} from "src/portals/IERC1155SinglePortal.sol";

import {InputBoxTestUtils} from "../util/InputBoxTestUtils.sol";
import {LibBytes} from "../util/LibBytes.sol";
import {LibTopic} from "../util/LibTopic.sol";
import {SimpleSingleERC1155} from "../util/SimpleERC1155.sol";

contract ERC1155SinglePortalTest is Test, InputBoxTestUtils {
    using LibTopic for address;
    using LibBytes for bytes;

    IInputBox _inputBox;
    IERC1155SinglePortal _portal;

    function setUp() public {
        _inputBox = new InputBox();
        _portal = new ERC1155SinglePortal(_inputBox);
    }

    function testGetInputBox() public view {
        assertEq(address(_portal.getInputBox()), address(_inputBox));
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
        _portal.depositSingleERC1155Token(
            token, appContract, tokenId, value, baseLayerData, execLayerData
        );
    }

    function testDepositRevertApplicationReverted(
        uint256 tokenId,
        uint256 value,
        bytes calldata baseLayerData,
        bytes calldata execLayerData,
        bytes calldata error
    ) external {
        address sender = _randomAccountWithNoCode();
        address appContract = _newAppMockReverts(error);

        IERC1155 token = _randomSetup(sender, tokenId, value);

        _mockOnErc1155Received(appContract, sender, tokenId, value, baseLayerData);

        vm.prank(sender);
        vm.expectRevert(_encodeApplicationReverted(appContract, error));
        _portal.depositSingleERC1155Token(
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
        address appContract = _newAppMockReturns(returnData);

        IERC1155 token = _randomSetup(sender, tokenId, value);

        _mockOnErc1155Received(appContract, sender, tokenId, value, baseLayerData);

        vm.prank(sender);
        vm.expectRevert(_encodeIllformedApplicationReturnData(appContract, returnData));
        _portal.depositSingleERC1155Token(
            token, appContract, tokenId, value, baseLayerData, execLayerData
        );
    }

    function testDepositRevertIllformedApplicationReturnDataInvalidBool(
        uint256 tokenId,
        uint256 value,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external {
        uint256 returnValue = vm.randomUint(2, type(uint256).max);
        bytes memory returnData = abi.encode(returnValue);

        address sender = _randomAccountWithNoCode();
        address appContract = _newAppMockReturns(returnData);

        IERC1155 token = _randomSetup(sender, tokenId, value);

        _mockOnErc1155Received(appContract, sender, tokenId, value, baseLayerData);

        vm.prank(sender);
        vm.expectRevert(_encodeIllformedApplicationReturnData(appContract, returnData));
        _portal.depositSingleERC1155Token(
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
        _portal.depositSingleERC1155Token(
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
        _portal.depositSingleERC1155Token(
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
                    revert("unexpected token contract topic #0");
                }
            } else {
                revert("unexpected log emitter");
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
        // Deploy the ERC-1155 token contract with the sender's tokens pre-minted
        token = new SimpleSingleERC1155(sender, tokenId, value);

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
