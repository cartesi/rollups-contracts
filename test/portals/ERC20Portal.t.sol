// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";

import {Vm} from "forge-std-1.9.6/src/Vm.sol";

import {IInputBox} from "src/inputs/IInputBox.sol";
import {IERC20Portal} from "src/portals/IERC20Portal.sol";

import {InputBoxTestUtils} from "../util/InputBoxTestUtils.sol";
import {LibBytes} from "../util/LibBytes.sol";
import {LibTopic} from "../util/LibTopic.sol";
import {RollupsTest} from "../util/RollupsTest.sol";
import {VersionGetterTestUtils} from "../util/VersionGetterTestUtils.sol";

contract ERC20PortalTest is RollupsTest, InputBoxTestUtils, VersionGetterTestUtils {
    using LibTopic for address;
    using LibBytes for bytes;

    IInputBox _inputBox;
    IERC20Portal _portal;
    IERC20 _token;

    function setUp() public {
        _inputBox = _contracts.core.inputBox;
        _portal = _contracts.core.erc20Portal;
        _token = _contracts.dev.testFungibleToken;
    }

    function testVersion() external view {
        _testVersion(_portal);
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
        bytes calldata errorData
    ) external {
        address sender = _randomAccountWithNoCode();
        address appContract = vm.randomBool()
            ? _newAppMockGetInputBoxReverts(errorData)
            : _newAppMockIsForeclosedReverts(errorData);

        _randomSetup(sender, appContract, value);

        vm.prank(sender);
        vm.expectRevert(_encodeApplicationReverted(appContract, errorData));
        _portal.depositERC20Tokens(_token, appContract, value, execLayerData);
    }

    function testDepositRevertIllformedApplicationReturnDataSize(
        uint256 value,
        bytes calldata execLayerData,
        bytes calldata returnData
    ) external {
        vm.assume(returnData.length != 32);

        address sender = _randomAccountWithNoCode();
        address appContract = vm.randomBool()
            ? _newAppMockGetInputBoxReturns(returnData)
            : _newAppMockIsForeclosedReturns(returnData);

        _randomSetup(sender, appContract, value);

        vm.prank(sender);
        vm.expectRevert(_encodeIllformedApplicationReturnData(appContract, returnData));
        _portal.depositERC20Tokens(_token, appContract, value, execLayerData);
    }

    function testDepositRevertIllformedApplicationReturnData(
        uint256 value,
        bytes calldata execLayerData
    ) external {
        address sender = _randomAccountWithNoCode();
        (address appContract, bytes memory returnData) = vm.randomBool()
            ? _newAppMockGetInputBoxReturnsRandomIllformedData()
            : _newAppMockIsForeclosedReturnsRandomIllformedData();

        _randomSetup(sender, appContract, value);

        vm.prank(sender);
        vm.expectRevert(_encodeIllformedApplicationReturnData(appContract, returnData));
        _portal.depositERC20Tokens(_token, appContract, value, execLayerData);
    }

    function testDepositRevertInputBoxNotDeployed(
        uint256 value,
        bytes calldata execLayerData
    ) external {
        address sender = _randomAccountWithNoCode();
        address inputBox = _randomAccountWithNoCode();
        address appContract = _newAppMockGetInputBoxReturns(inputBox);

        _randomSetup(sender, appContract, value);

        vm.prank(sender);
        vm.expectRevert(_encodeInputBoxNotDeployed(inputBox));
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

    function testDepositRevertERC20TransferDecreasedApplicationBalance(
        uint256 value,
        bytes calldata execLayerData
    ) external {
        address sender = _randomAccountWithNoCode();
        address appContract = _newActiveAppMock();

        _randomSetup(sender, appContract, value);

        uint256 currentBalance = _token.balanceOf(appContract);

        // Pick a random value < current app balance
        // We therefore need to assume the current balance is non-zero
        vm.assume(currentBalance > 0);
        uint256 fakePostTransferBalance = vm.randomUint(0, currentBalance - 1);

        // Mock the two internal calls to balanceOf
        // The first call is made before the transfer
        // The second call is made after the transfer
        // We make the second call return the fake, smaller value
        bytes[] memory returnData = new bytes[](2);
        returnData[0] = abi.encode(currentBalance);
        returnData[1] = abi.encode(fakePostTransferBalance);
        vm.mockCalls(
            address(_token), abi.encodeCall(IERC20.balanceOf, (appContract)), returnData
        );

        vm.prank(sender);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Portal.ERC20TransferDecreasedApplicationBalance.selector,
                currentBalance,
                fakePostTransferBalance
            )
        );
        _portal.depositERC20Tokens(_token, appContract, value, execLayerData);
    }

    function testDepositRevertERC20TransferValueIsNotBalanceDelta(
        uint256 value,
        bytes calldata execLayerData
    ) external {
        address sender = _randomAccountWithNoCode();
        address appContract = _newActiveAppMock();

        _randomSetup(sender, appContract, value);

        uint256 currentBalance = _token.balanceOf(appContract);

        // Pick a random value >= current app balance
        // such that the balance delta is different from the transfer value
        uint256 fakePostTransferBalance = vm.randomUint(currentBalance, type(uint256).max);
        uint256 balanceDelta = fakePostTransferBalance - currentBalance;
        vm.assume(value != balanceDelta);

        // Mock the two internal calls to balanceOf
        // The first call is made before the transfer
        // The second call is made after the transfer
        // We make the second call return the fake, smaller value
        bytes[] memory returnData = new bytes[](2);
        returnData[0] = abi.encode(currentBalance);
        returnData[1] = abi.encode(fakePostTransferBalance);
        vm.mockCalls(
            address(_token), abi.encodeCall(IERC20.balanceOf, (appContract)), returnData
        );

        vm.prank(sender);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Portal.ERC20TransferValueIsNotBalanceDelta.selector,
                value,
                balanceDelta
            )
        );
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
                    revert UnexpectedLog(log);
                }
            } else {
                revert UnexpectedLog(log);
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

        // Pick random token amounts for each participant
        uint256 totalSupply = type(uint256).max;
        uint256 senderBalance = vm.randomUint(value, totalSupply);
        totalSupply -= senderBalance;
        uint256 portalBalance = vm.randomUint(0, totalSupply);
        totalSupply -= portalBalance;
        uint256 appBalance = vm.randomUint(0, totalSupply);
        totalSupply -= appBalance;

        // Mint the tokens
        _contracts.dev.testFungibleToken.mint(senderBalance + portalBalance + appBalance);

        // Transfer the tokens to each participant
        assertTrue(_token.transfer(sender, senderBalance));
        assertTrue(_token.transfer(address(_portal), portalBalance));
        assertTrue(_token.transfer(appContract, appBalance));

        // Make the sender give enough allowance to the portal
        vm.prank(sender);
        _token.approve(address(_portal), vm.randomUint(value, type(uint256).max));
    }
}
