// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {OutputValidityProof} from "src/common/OutputValidityProof.sol";
import {IApplication} from "src/dapp/IApplication.sol";
import {LibBytes} from "src/library/LibBytes.sol";

contract OutputExecutionChecker {
    using LibBytes for bytes;

    bool _initialized;
    IApplication _appContract;
    bytes _output;
    OutputValidityProof _proof;

    error AlreadyInitialized();
    error NotInitialized();
    error OutputNotMarkedAsExecuted();
    error OutputReexecuted();
    error NotError(bytes errorData);
    error UnexpectedErrorSelector(bytes errorData);
    error UnexpectedErrorArgs(bytes errorData);

    function initialize(
        IApplication appContract,
        bytes calldata output,
        OutputValidityProof calldata proof
    ) external {
        require(!_initialized, AlreadyInitialized());
        _initialized = true;
        _appContract = appContract;
        _output = output;
        _proof.outputIndex = proof.outputIndex;
        for (uint256 i; i < proof.outputHashesSiblings.length; ++i) {
            bytes32 sibling = proof.outputHashesSiblings[i];
            _proof.outputHashesSiblings.push(sibling);
        }
    }

    receive() external payable {
        require(_initialized, NotInitialized());
        require(
            _appContract.wasOutputExecuted(_proof.outputIndex),
            OutputNotMarkedAsExecuted()
        );
        try _appContract.executeOutput(_output, _proof) {
            revert OutputReexecuted();
        } catch (bytes memory errorData) {
            bool isError;
            bytes4 errorSelector;
            bytes memory errorArgs;
            (isError, errorSelector, errorArgs) = errorData.consumeBytes4();
            require(isError, NotError(errorData));
            require(
                errorSelector == IApplication.OutputNotReexecutable.selector,
                UnexpectedErrorSelector(errorData)
            );
            require(
                keccak256(errorArgs) == keccak256(abi.encode(_output)),
                UnexpectedErrorArgs(errorData)
            );
        }
    }
}
