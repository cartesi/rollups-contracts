// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {IERC721} from "@openzeppelin-contracts-5.2.0/token/ERC721/IERC721.sol";
import {
    IERC721Receiver
} from "@openzeppelin-contracts-5.2.0/token/ERC721/IERC721Receiver.sol";

import {Test} from "forge-std-1.9.6/src/Test.sol";
import {Vm} from "forge-std-1.9.6/src/Vm.sol";

import {IInputBox} from "src/inputs/IInputBox.sol";
import {InputBox} from "src/inputs/InputBox.sol";
import {ERC721Portal} from "src/portals/ERC721Portal.sol";
import {IERC721Portal} from "src/portals/IERC721Portal.sol";

import {InputBoxTestUtils} from "../util/InputBoxTestUtils.sol";
import {LibBytes} from "../util/LibBytes.sol";
import {LibTopic} from "../util/LibTopic.sol";
import {SimpleERC721} from "../util/SimpleERC721.sol";
import {VersionGetterTestUtils} from "../util/VersionGetterTestUtils.sol";

contract ERC721PortalTest is Test, InputBoxTestUtils, VersionGetterTestUtils {
    using LibTopic for address;
    using LibBytes for bytes;

    IInputBox _inputBox;
    IERC721Portal _portal;

    function setUp() public {
        _inputBox = new InputBox();
        _portal = new ERC721Portal(_inputBox);
    }

    function testVersion() external view {
        _testVersion(_portal);
    }

    function testGetInputBox() public view {
        assertEq(address(_portal.getInputBox()), address(_inputBox));
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
        bytes calldata error
    ) external {
        address sender = _randomAccountWithNoCode();
        address appContract = _newAppMockReverts(error);

        IERC721 token = _randomSetup(sender, tokenId);

        _mockOnErc721Received(appContract, sender, tokenId, baseLayerData);

        vm.prank(sender);
        vm.expectRevert(_encodeApplicationReverted(appContract, error));
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
        address appContract = _newAppMockReturns(returnData);

        IERC721 token = _randomSetup(sender, tokenId);

        _mockOnErc721Received(appContract, sender, tokenId, baseLayerData);

        vm.prank(sender);
        vm.expectRevert(_encodeIllformedApplicationReturnData(appContract, returnData));
        _portal.depositERC721Token(
            token, appContract, tokenId, baseLayerData, execLayerData
        );
    }

    function testDepositRevertIllformedApplicationReturnDataInvalidBool(
        uint256 tokenId,
        bytes calldata baseLayerData,
        bytes calldata execLayerData
    ) external {
        uint256 returnValue = vm.randomUint(2, type(uint256).max);
        bytes memory returnData = abi.encode(returnValue);

        address sender = _randomAccountWithNoCode();
        address appContract = _newAppMockReturns(returnData);

        IERC721 token = _randomSetup(sender, tokenId);

        _mockOnErc721Received(appContract, sender, tokenId, baseLayerData);

        vm.prank(sender);
        vm.expectRevert(_encodeIllformedApplicationReturnData(appContract, returnData));
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
        // Deploy the ERC-721 token contract with the sender's NFT pre-minted
        token = new SimpleERC721(sender, tokenId);

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
