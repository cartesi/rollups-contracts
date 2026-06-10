// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.8;

import {VmSafe} from "forge-std-1.9.6/src/Vm.sol";

import {TestFungibleToken} from "src/devnet/TestFungibleToken.sol";
import {TestMultiToken} from "src/devnet/TestMultiToken.sol";
import {TestNonFungibleToken} from "src/devnet/TestNonFungibleToken.sol";
import {
    IUsdWithdrawalOutputBuilder
} from "src/withdrawal/IUsdWithdrawalOutputBuilder.sol";
import {UsdWithdrawalOutputBuilder} from "src/withdrawal/UsdWithdrawalOutputBuilder.sol";

import "./ContractDeployers.sol" as G;
import "./CoreContracts.sol" as CoreContracts;
import {storeDeployment} from "./DeploymentStorage.sol";

struct Suite {
    TestFungibleToken testFungibleToken;
    TestMultiToken testMultiToken;
    TestNonFungibleToken testNonFungibleToken;
    IUsdWithdrawalOutputBuilder testUsdWithdrawalOutputBuilder;
}

function deploy(CoreContracts.Suite memory core) returns (Suite memory) {
    TestFungibleToken testFungibleToken = G.deployTestFungibleToken();
    TestNonFungibleToken testNonFungibleToken = G.deployTestNonFungibleToken();
    TestMultiToken testMultiToken = G.deployTestMultiToken();
    IUsdWithdrawalOutputBuilder testUsdWithdrawalOutputBuilder =
        G.deployUsdWithdrawalOutputBuilder(
            core.usdWithdrawalOutputBuilderFactory, testFungibleToken
        );

    return Suite({
        testFungibleToken: testFungibleToken,
        testMultiToken: testMultiToken,
        testNonFungibleToken: testNonFungibleToken,
        testUsdWithdrawalOutputBuilder: testUsdWithdrawalOutputBuilder
    });
}

function store(VmSafe vmSafe, Suite memory s) {
    storeDeployment(vmSafe, type(TestFungibleToken).name, address(s.testFungibleToken));
    storeDeployment(vmSafe, type(TestMultiToken).name, address(s.testMultiToken));
    storeDeployment(
        vmSafe, type(TestNonFungibleToken).name, address(s.testNonFungibleToken)
    );
    storeDeployment(
        vmSafe,
        string.concat("Test", type(UsdWithdrawalOutputBuilder).name),
        address(s.testUsdWithdrawalOutputBuilder)
    );
}
