// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.8;

import {Vm} from "forge-std/Vm.sol";

import {Quorum} from "contracts/consensus/quorum/Quorum.sol";
import {History} from "contracts/history/History.sol";
import {IHistory} from "contracts/history/IHistory.sol";

import {TestBase} from "../../util/TestBase.sol";

import "forge-std/console.sol";

contract QuorumTest is TestBase {
    Quorum quorum;
    uint256 constant numOfValidators = 3;
    address[] validators;
    uint256[] shares;

    function setUp() external {
        for (uint256 i; i < numOfValidators; ++i) {
            validators.push(vm.addr(i + 1));
            shares.push(i + 1);
        }

        quorum = new Quorum(validators, shares, IHistory(vm.addr(1)));
    }

    function testSubmitClaim(
        address _dapp,
        History.Claim calldata _claim
    ) external {
        bytes memory claimData = abi.encode(_dapp, _claim);

        vm.mockCall(
            address(quorum.getHistory()),
            abi.encodeWithSelector(IHistory.submitClaim.selector, claimData),
            abi.encode()
        );

        for (uint256 i; i < numOfValidators; ++i) {
            vm.prank(validators[i]);
            quorum.submitClaim(claimData);
        }
    }
}
