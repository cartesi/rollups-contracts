// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {IApplication} from "src/dapp/IApplication.sol";
import {IApplicationChecker} from "src/dapp/IApplicationChecker.sol";

import {RollupsTest} from "./RollupsTest.sol";

contract ApplicationCheckerTestUtils is RollupsTest {
    function _encodeApplicationNotDeployed(address appContract)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IApplicationChecker.ApplicationNotDeployed.selector, appContract
        );
    }

    function _encodeApplicationReverted(address appContract, bytes memory errorData)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IApplicationChecker.ApplicationReverted.selector, appContract, errorData
        );
    }

    function _encodeIllformedApplicationReturnData(
        address appContract,
        bytes memory returnData
    ) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            IApplicationChecker.IllformedApplicationReturnData.selector,
            appContract,
            returnData
        );
    }

    function _encodeInputBoxNotDeployed(address inputBox)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IApplicationChecker.InputBoxNotDeployed.selector, inputBox
        );
    }

    function _encodeApplicationForeclosed(address appContract)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IApplicationChecker.ApplicationForeclosed.selector, appContract
        );
    }

    function _encodeIsForeclosed() internal pure returns (bytes memory) {
        return abi.encodeCall(IApplication.isForeclosed, ());
    }

    function _encodeGetInputBox() internal pure returns (bytes memory) {
        return abi.encodeCall(IApplication.getInputBox, ());
    }

    function _randomAccountWithNoCode() internal returns (address) {
        address account = vm.addr(boundPrivateKey(vm.randomUint()));
        vm.assume(account.code.length == 0);
        return account;
    }

    function _newAppMockGetInputBoxReverts(bytes memory errorData)
        internal
        returns (address appContract)
    {
        appContract = _randomAccountWithNoCode();
        vm.mockCallRevert(appContract, _encodeGetInputBox(), errorData);
    }

    function _newAppMockGetInputBoxReturns(bytes memory returnData)
        internal
        returns (address appContract)
    {
        appContract = _randomAccountWithNoCode();
        vm.mockCall(appContract, _encodeGetInputBox(), returnData);
    }

    function _newAppMockGetInputBoxReturnsRandomIllformedData()
        internal
        returns (address appContract, bytes memory returnData)
    {
        uint256 maxUint160 = type(uint160).max;
        returnData = abi.encode(vm.randomUint(maxUint160 + 1, type(uint256).max));
        appContract = _newAppMockGetInputBoxReturns(returnData);
    }

    function _newAppMockGetInputBoxReturns(address inputBox) internal returns (address) {
        return _newAppMockGetInputBoxReturns(abi.encode(inputBox));
    }

    function _newAppMockGetInputBoxReturnsCore() internal returns (address) {
        return _newAppMockGetInputBoxReturns(address(_contracts.core.inputBox));
    }

    function _newAppMockIsForeclosedReverts(bytes memory errorData)
        internal
        returns (address appContract)
    {
        appContract = _newAppMockGetInputBoxReturnsCore();
        vm.mockCallRevert(appContract, _encodeIsForeclosed(), errorData);
    }

    function _newAppMockIsForeclosedReturns(bytes memory returnData)
        internal
        returns (address appContract)
    {
        appContract = _newAppMockGetInputBoxReturnsCore();
        vm.mockCall(appContract, _encodeIsForeclosed(), returnData);
    }

    function _newAppMockIsForeclosedReturnsRandomIllformedData()
        internal
        returns (address appContract, bytes memory returnData)
    {
        returnData = abi.encode(vm.randomUint(2, type(uint256).max));
        appContract = _newAppMockIsForeclosedReturns(returnData);
    }

    function _newForeclosedAppMock() internal returns (address) {
        return _newAppMockIsForeclosedReturns(abi.encode(true));
    }

    function _newActiveAppMock() internal returns (address) {
        return _newAppMockIsForeclosedReturns(abi.encode(false));
    }
}
