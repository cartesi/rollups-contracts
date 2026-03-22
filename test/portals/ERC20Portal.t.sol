// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";

import {Test} from "forge-std-1.9.6/src/Test.sol";
import {Vm} from "forge-std-1.9.6/src/Vm.sol";

import {IInputBox} from "src/inputs/IInputBox.sol";
import {InputBox} from "src/inputs/InputBox.sol";
import {ERC20Portal} from "src/portals/ERC20Portal.sol";
import {IERC20Portal} from "src/portals/IERC20Portal.sol";

import {InputBoxTestUtils} from "../util/InputBoxTestUtils.sol";
import {LibBytes} from "../util/LibBytes.sol";
import {LibTopic} from "../util/LibTopic.sol";
import {SimpleERC20} from "../util/SimpleERC20.sol";
import {VersionGetterTestUtils} from "../util/VersionGetterTestUtils.sol";

contract ERC20PortalTest is Test, InputBoxTestUtils, VersionGetterTestUtils {
    using LibTopic for address;
    using LibBytes for bytes;

    IInputBox _inputBox;
    IERC20Portal _portal;
    IERC20 _token;

    address immutable TOKEN_OWNER = vm.addr(1);
    uint256 immutable TOTAL_SUPPLY = type(uint256).max;

    function setUp() public {
        _inputBox = new InputBox();
        _portal = new ERC20Portal(_inputBox);
        _token = new SimpleERC20(TOKEN_OWNER, TOTAL_SUPPLY);
    }

    function testVersion() external view {
        _testVersion(_portal);
    }

    function testGetInputBox() public view {
        assertEq(address(_portal.getInputBox()), address(_inputBox));
    }

    function testDepositRevertApplicationNotDeployed(
        uint256 value,
        bytes calldata execLayerData
    ) external {
        address sender = _randomAccountWithNoCode();
        address appContract = _randomAccountWithNoCode();

        _randomSetup(sender, appContract, value);

        vm.prank(sender);
        vm.expectRevert(_encodeApplicationNotDeployed(appContract));
        _portal.depositERC20Tokens(_token, appContract, value, execLayerData);
    }

    function testDepositRevertApplicationReverted(
        uint256 value,
        bytes calldata execLayerData,
        bytes calldata error
    ) external {
        address sender = _randomAccountWithNoCode();
        address appContract = _newAppMockReverts(error);

        _randomSetup(sender, appContract, value);

        vm.prank(sender);
        vm.expectRevert(_encodeApplicationReverted(appContract, error));
        _portal.depositERC20Tokens(_token, appContract, value, execLayerData);
    }

    function testDepositRevertIllformedApplicationReturnDataSize(
        uint256 value,
        bytes calldata execLayerData,
        bytes calldata returnData
    ) external {
        vm.assume(returnData.length != 32);

        address sender = _randomAccountWithNoCode();
        address appContract = _newAppMockReturns(returnData);

        _randomSetup(sender, appContract, value);

        vm.prank(sender);
        vm.expectRevert(_encodeIllformedApplicationReturnData(appContract, returnData));
        _portal.depositERC20Tokens(_token, appContract, value, execLayerData);
    }

    function testDepositRevertIllformedApplicationReturnDataInvalidBool(
        uint256 value,
        bytes calldata execLayerData
    ) external {
        uint256 returnValue = vm.randomUint(2, type(uint256).max);
        bytes memory returnData = abi.encode(returnValue);

        address sender = _randomAccountWithNoCode();
        address appContract = _newAppMockReturns(returnData);

        _randomSetup(sender, appContract, value);

        vm.prank(sender);
        vm.expectRevert(_encodeIllformedApplicationReturnData(appContract, returnData));
        _portal.depositERC20Tokens(_token, appContract, value, execLayerData);
    }

    function testDepositRevertApplicationForeclosed(
        uint256 value,
        bytes calldata execLayerData
    ) external {
        address sender = _randomAccountWithNoCode();
        address appContract = _newForeclosedAppMock();

        _randomSetup(sender, appContract, value);

        vm.prank(sender);
        vm.expectRevert(_encodeApplicationForeclosed(appContract));
        _portal.depositERC20Tokens(_token, appContract, value, execLayerData);
    }

    function testDepositRevertERC20TokenReverts(
        uint256 value,
        bytes calldata execLayerData,
        bytes calldata errorData
    ) external {
        address sender = _randomAccountWithNoCode();
        address appContract = _newActiveAppMock();

        _randomSetup(sender, appContract, value);

        vm.mockCallRevert(
            address(_token),
            abi.encodeCall(IERC20.transferFrom, (sender, appContract, value)),
            errorData
        );

        vm.prank(sender);
        vm.expectRevert(errorData);
        _portal.depositERC20Tokens(_token, appContract, value, execLayerData);
    }

    function testDepositRevertERC20TokenReturnsFalse(
        uint256 value,
        bytes calldata execLayerData
    ) external {
        address sender = _randomAccountWithNoCode();
        address appContract = _newActiveAppMock();

        _randomSetup(sender, appContract, value);

        vm.mockCall(
            address(_token),
            abi.encodeCall(IERC20.transferFrom, (sender, appContract, value)),
            abi.encode(false)
        );

        vm.prank(sender);
        vm.expectRevert(IERC20Portal.ERC20TransferFailed.selector);
        _portal.depositERC20Tokens(_token, appContract, value, execLayerData);
    }

    function testDeposit(
        uint256 value,
        bytes calldata execLayerData,
        bytes[] calldata payloads
    ) external {
        address sender = _randomAccountWithNoCode();
        address appContract = _newActiveAppMock();

        _randomSetup(sender, appContract, value);
        _addInputs(_inputBox, appContract, payloads);

        uint256 senderBalance = _token.balanceOf(sender);
        uint256 appContractBalance = _token.balanceOf(appContract);

        uint256 numOfInputs = _inputBox.getNumberOfInputs(appContract);

        vm.recordLogs();

        vm.prank(sender);
        _portal.depositERC20Tokens(_token, appContract, value, execLayerData);

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
            } else if (log.emitter == address(_token)) {
                bytes32 topic0 = log.topics[0];
                if (topic0 == IERC20.Transfer.selector) {
                    uint256 arg1 = abi.decode(log.data, (uint256));
                    assertEq(log.topics[1], sender.asTopic());
                    assertEq(log.topics[2], appContract.asTopic());
                    assertEq(arg1, value);
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

        assertEq(_token.balanceOf(sender), senderBalance - value);
        assertEq(_token.balanceOf(appContract), appContractBalance + value);

        assertEq(_inputBox.getNumberOfInputs(appContract), numOfInputs + 1);
        assertEq(keccak256(input), _inputBox.getInputHash(appContract, numOfInputs));

        bytes memory buffer = payload;
        address tokenArg;
        address senderArg;
        uint256 valueArg;
        bytes memory execLayerDataArg;

        (tokenArg, buffer) = buffer.consumeAddress();
        (senderArg, buffer) = buffer.consumeAddress();
        (valueArg, execLayerDataArg) = buffer.consumeUint256();

        assertEq(tokenArg, address(_token));
        assertEq(senderArg, sender);
        assertEq(valueArg, value);
        assertEq(execLayerDataArg, execLayerData);
    }

    function _randomSetup(address sender, address appContract, uint256 value) internal {
        // Mine a random number of blocks
        vm.roll(vm.randomUint(vm.getBlockNumber(), type(uint256).max));

        // Transfer a random amount of tokens to each participant
        vm.startPrank(TOKEN_OWNER);
        assertTrue(_token.transfer(sender, _randomAmountGe(value)));
        assertTrue(_token.transfer(address(_portal), _randomAmountGe(0)));
        assertTrue(_token.transfer(appContract, _randomAmountGe(0)));
        vm.stopPrank();

        // Make the sender give enough allowance to the portal
        vm.prank(sender);
        _token.approve(address(_portal), vm.randomUint(value, type(uint256).max));
    }

    function _randomAmountGe(uint256 min) internal returns (uint256) {
        return vm.randomUint(min, _token.balanceOf(TOKEN_OWNER));
    }
}
