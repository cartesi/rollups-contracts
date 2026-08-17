// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.30;

import {AccountValidityProof} from "../../src/common/AccountValidityProof.sol";
import {IApplication} from "../../src/dapp/IApplication.sol";
import {LibBytes} from "../../src/library/LibBytes.sol";

contract WithdrawalChecker {
    using LibBytes for bytes;

    bool _initialized;
    IApplication _appContract;
    bytes _account;
    AccountValidityProof _proof;

    error AlreadyInitialized();
    error NotInitialized();
    error AccountFundsNotMarkedAsWithdrawn();
    error AccountFundsWithdrawnTwice();
    error NotError(bytes errorData);
    error UnexpectedErrorSelector(bytes errorData);
    error UnexpectedErrorArgs(bytes errorData);

    function initialize(
        IApplication appContract,
        bytes calldata account,
        AccountValidityProof calldata proof
    ) external {
        require(!_initialized, AlreadyInitialized());
        _initialized = true;
        _appContract = appContract;
        _account = account;
        _proof.accountIndex = proof.accountIndex;
        for (uint256 i; i < proof.accountRootSiblings.length; ++i) {
            bytes32 sibling = proof.accountRootSiblings[i];
            _proof.accountRootSiblings.push(sibling);
        }
    }

    receive() external payable {
        require(_initialized, NotInitialized());
        require(
            _appContract.wereAccountFundsWithdrawn(_proof.accountIndex),
            AccountFundsNotMarkedAsWithdrawn()
        );
        try _appContract.withdraw(_account, _proof) {
            revert AccountFundsWithdrawnTwice();
        } catch (bytes memory errorData) {
            bool isError;
            bytes4 errorSelector;
            bytes memory errorArgs;
            (isError, errorSelector, errorArgs) = errorData.consumeBytes4();
            require(isError, NotError(errorData));
            require(
                errorSelector == IApplication.AccountFundsAlreadyWithdrawn.selector,
                UnexpectedErrorSelector(errorData)
            );
            require(
                keccak256(errorArgs) == keccak256(abi.encode(_proof.accountIndex)),
                UnexpectedErrorArgs(errorData)
            );
        }
    }
}
