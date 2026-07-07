// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {IApplication} from "src/dapp/IApplication.sol";
import {LibBytes} from "src/library/LibBytes.sol";

contract RefundIssuanceChecker {
    using LibBytes for bytes;

    bool _initialized;
    IApplication _appContract;
    uint256 _inputIndex;
    bytes _input;

    error AlreadyInitialized();
    error NotInitialized();
    error RefundForInputNotMarkedAsIssued();
    error RefundReissued();
    error NotError(bytes errorData);
    error UnexpectedErrorSelector(bytes errorData);
    error UnexpectedErrorArgs(bytes errorData);

    function initialize(
        IApplication appContract,
        uint256 inputIndex,
        bytes calldata input
    ) external {
        require(!_initialized, AlreadyInitialized());
        _initialized = true;
        _appContract = appContract;
        _inputIndex = inputIndex;
        _input = input;
    }

    receive() external payable {
        require(_initialized, NotInitialized());
        require(
            _appContract.wasRefundForInputIssued(_inputIndex),
            RefundForInputNotMarkedAsIssued()
        );
        try _appContract.issueRefund(_inputIndex, _input) {
            revert RefundReissued();
        } catch (bytes memory errorData) {
            bool isError;
            bytes4 errorSelector;
            bytes memory errorArgs;
            (isError, errorSelector, errorArgs) = errorData.consumeBytes4();
            require(isError, NotError(errorData));
            require(
                errorSelector == IApplication.RefundAlreadyIssued.selector,
                UnexpectedErrorSelector(errorData)
            );
            require(
                keccak256(errorArgs) == keccak256(abi.encode(_inputIndex)),
                UnexpectedErrorArgs(errorData)
            );
        }
    }
}
