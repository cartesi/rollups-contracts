// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {IApplicationChecker} from "src/dapp/IApplicationChecker.sol";
import {IApplicationForeclosure} from "src/dapp/IApplicationForeclosure.sol";

import {Test} from "forge-std-1.9.6/src/Test.sol";

contract ApplicationCheckerTestUtils is Test {
    function _encodeApplicationNotDeployed(address appContract)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IApplicationChecker.ApplicationNotDeployed.selector, appContract
        );
    }

    function _encodeApplicationReverted(address appContract, bytes memory error)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IApplicationChecker.ApplicationReverted.selector, appContract, error
        );
    }

    function _encodeIllformedApplicationReturnData(
        address appContract,
        bytes memory data
    ) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            IApplicationChecker.IllformedApplicationReturnData.selector, appContract, data
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
        return abi.encodeCall(IApplicationForeclosure.isForeclosed, ());
    }

    function _randomAccountWithNoCode() internal returns (address) {
        address account = vm.addr(boundPrivateKey(vm.randomUint()));
        vm.assume(account.code.length == 0);
        return account;
    }

    function _newAppMockReturns(bytes memory data) internal returns (address) {
        address appContract = _randomAccountWithNoCode();
        vm.mockCall(appContract, _encodeIsForeclosed(), data);
        assertGt(appContract.code.length, 0);
        return appContract;
    }

    function _newAppMockReverts(bytes memory error) internal returns (address) {
        address appContract = _randomAccountWithNoCode();
        vm.mockCallRevert(appContract, _encodeIsForeclosed(), error);
        assertGt(appContract.code.length, 0);
        return appContract;
    }

    function _newForeclosedAppMock() internal returns (address) {
        return _newAppMockReturns(abi.encode(true));
    }

    function _newActiveAppMock() internal returns (address) {
        return _newAppMockReturns(abi.encode(false));
    }
}
