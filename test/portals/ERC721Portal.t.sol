// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {IERC721} from "@openzeppelin-contracts-5.2.0/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin-contracts-5.2.0/token/ERC721/IERC721Receiver.sol";

import {Vm} from "forge-std-1.9.6/src/Vm.sol";

import {IInputBox} from "src/inputs/IInputBox.sol";
import {IERC721Portal} from "src/portals/IERC721Portal.sol";

import {InputBoxTestUtils} from "../util/InputBoxTestUtils.sol";
import {LibBytes} from "../util/LibBytes.sol";
import {LibTopic} from "../util/LibTopic.sol";
import {RollupsTest} from "../util/RollupsTest.sol";
import {VersionGetterTestUtils} from "../util/VersionGetterTestUtils.sol";

contract ERC721PortalTest is RollupsTest, InputBoxTestUtils, VersionGetterTestUtils {
    using LibTopic for address;
    using LibBytes for bytes;

    IInputBox _inputBox;
    IERC721Portal _portal;

    function setUp() public {
        _inputBox = _contracts.core.inputBox;
        _portal = _contracts.core.erc721Portal;
    }

    function testVersion() external view {
        _testVersion(_portal);
    }

    function testDepositRevertApplicationNotDeployed(
        uint256 tokenId,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external {
        address sender = _randomAccountWithNoCode();
        address appContract = _randomAccountWithNoCode();

        IERC721 token = _randomSetup(sender, tokenId);

        vm.prank(sender);
        vm.expectRevert(_encodeApplicationNotDeployed(appContract));
        _portal.depositERC721Token(
            token, appContract, tokenId, baseLayerData, execLayerData
        );
    }

    function testDepositRevertApplicationReverted(
        uint256 tokenId,
        bytes calldata baseLayerData,
        bytes calldata execLayerData,
        bytes calldata errorData
    ) external {
        address sender = _randomAccountWithNoCode();
        address appContract = vm.randomBool()
            ? _newAppMockGetInputBoxReverts(errorData)
            : _newAppMockIsForeclosedReverts(errorData);

        IERC721 token = _randomSetup(sender, tokenId);

        _mockOnErc721Received(appContract, sender, tokenId, baseLayerData);

        vm.prank(sender);
        vm.expectRevert(_encodeApplicationReverted(appContract, errorData));
        _portal.depositERC721Token(
            token, appContract, tokenId, baseLayerData, execLayerData
        );
    }

    function testDepositRevertIllformedApplicationReturnDataSize(
        uint256 tokenId,
        bytes calldata baseLayerData,
        bytes calldata execLayerData,
        bytes calldata returnData
    ) external {
        vm.assume(returnData.length != 32);

        address sender = _randomAccountWithNoCode();
        address appContract = vm.randomBool()
            ? _newAppMockGetInputBoxReturns(returnData)
            : _newAppMockIsForeclosedReturns(returnData);

        IERC721 token = _randomSetup(sender, tokenId);

        _mockOnErc721Received(appContract, sender, tokenId, baseLayerData);

        vm.prank(sender);
        vm.expectRevert(_encodeIllformedApplicationReturnData(appContract, returnData));
        _portal.depositERC721Token(
            token, appContract, tokenId, baseLayerData, execLayerData
        );
    }

    function testDepositRevertIllformedApplicationReturnData(
        uint256 tokenId,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external {
        address sender = _randomAccountWithNoCode();
        (address appContract, bytes memory returnData) = vm.randomBool()
            ? _newAppMockGetInputBoxReturnsRandomIllformedData()
            : _newAppMockIsForeclosedReturnsRandomIllformedData();

        IERC721 token = _randomSetup(sender, tokenId);

        _mockOnErc721Received(appContract, sender, tokenId, baseLayerData);

        vm.prank(sender);
        vm.expectRevert(_encodeIllformedApplicationReturnData(appContract, returnData));
        _portal.depositERC721Token(
            token, appContract, tokenId, baseLayerData, execLayerData
        );
    }

    function testDepositRevertInputBoxNotDeployed(
        uint256 tokenId,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external {
        address sender = _randomAccountWithNoCode();
        address inputBox = _randomAccountWithNoCode();
        address appContract = _newAppMockGetInputBoxReturns(inputBox);

        IERC721 token = _randomSetup(sender, tokenId);

        _mockOnErc721Received(appContract, sender, tokenId, baseLayerData);

        vm.prank(sender);
        vm.expectRevert(_encodeInputBoxNotDeployed(inputBox));
        _portal.depositERC721Token(
            token, appContract, tokenId, baseLayerData, execLayerData
        );
    }

    function testDepositRevertApplicationForeclosed(
        uint256 tokenId,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external {
        address sender = _randomAccountWithNoCode();
        address appContract = _newForeclosedAppMock();

        IERC721 token = _randomSetup(sender, tokenId);

        _mockOnErc721Received(appContract, sender, tokenId, baseLayerData);

        vm.prank(sender);
        vm.expectRevert(_encodeApplicationForeclosed(appContract));
        _portal.depositERC721Token(
            token, appContract, tokenId, baseLayerData, execLayerData
        );
    }

    function testDeposit(
        uint256 tokenId,
        bytes calldata baseLayerData,
        bytes calldata execLayerData,
        bytes[] calldata payloads
    ) external {
        address sender = _randomAccountWithNoCode();
        address appContract = _newActiveAppMock();

        IERC721 token = _randomSetup(sender, tokenId);

        _mockOnErc721Received(appContract, sender, tokenId, baseLayerData);

        _addInputs(_inputBox, appContract, payloads);

        assertEq(token.ownerOf(tokenId), sender);

        uint256 senderBalance = token.balanceOf(sender);
        uint256 appContractBalance = token.balanceOf(appContract);

        uint256 numOfInputs = _inputBox.getNumberOfInputs(appContract);

        vm.recordLogs();

        vm.prank(sender);
        _portal.depositERC721Token(
            token, appContract, tokenId, baseLayerData, execLayerData
        );

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes memory input;
        bytes memory payload;
        uint256 numOfInputAdded;
        uint256 numOfTransfer;

        for (uint256 i; i < logs.length; ++i) {
            Vm.Log memory log = logs[i];
            if (log.emitter == address(_inputBox)) {
                (input, payload) =
                    _decodeInputAdded(log, appContract, address(_portal), numOfInputs);
                ++numOfInputAdded;
            } else if (log.emitter == address(token)) {
                bytes32 topic0 = log.topics[0];
                if (topic0 == IERC721.Transfer.selector) {
                    assertEq(log.topics[1], sender.asTopic());
                    assertEq(log.topics[2], appContract.asTopic());
                    assertEq(log.topics[3], bytes32(tokenId));
                    assertEq(log.data.length, 0);
                    ++numOfTransfer;
                } else {
                    revert("unexpected token contract topic #0");
                }
            } else {
                revert("unexpected log emitter");
            }
        }

        assertEq(numOfInputAdded, 1);
        assertEq(numOfTransfer, 1);

        assertEq(token.balanceOf(sender), senderBalance - 1);
        assertEq(token.balanceOf(appContract), appContractBalance + 1);
        assertEq(token.ownerOf(tokenId), appContract);

        assertEq(_inputBox.getNumberOfInputs(appContract), numOfInputs + 1);
        assertEq(keccak256(input), _inputBox.getInputHash(appContract, numOfInputs));

        bytes memory buffer = payload;
        address tokenArg;
        address senderArg;
        uint256 tokenIdArg;
        bytes memory baseLayerDataArg;
        bytes memory execLayerDataArg;

        (tokenArg, buffer) = buffer.consumeAddress();
        (senderArg, buffer) = buffer.consumeAddress();
        (tokenIdArg, buffer) = buffer.consumeUint256();
        (baseLayerDataArg, execLayerDataArg) = abi.decode(buffer, (bytes, bytes));

        assertEq(tokenArg, address(token));
        assertEq(senderArg, sender);
        assertEq(tokenIdArg, tokenId);
        assertEq(baseLayerDataArg, baseLayerData);
        assertEq(execLayerDataArg, execLayerData);
    }

    function _randomSetup(address sender, uint256 tokenId)
        internal
        returns (IERC721 token)
    {
        // Get the pre-deployed ERC-721 token contract
        token = _contracts.dev.testNonFungibleToken;

        // Make the sender mint the token
        vm.prank(sender);
        _contracts.dev.testNonFungibleToken.mint(tokenId);

        // Mine a random number of blocks
        vm.roll(vm.randomUint(vm.getBlockNumber(), type(uint256).max));

        // Make the sender give approval to the portal
        vm.prank(sender);
        token.approve(address(_portal), tokenId);
    }

    function _mockOnErc721Received(
        address appContract,
        address sender,
        uint256 tokenId,
        bytes memory baseLayerData
    ) internal {
        vm.mockCall(
            appContract,
            abi.encodeCall(
                IERC721Receiver.onERC721Received,
                (address(_portal), sender, tokenId, baseLayerData)
            ),
            abi.encode(IERC721Receiver.onERC721Received.selector)
        );
    }
}
