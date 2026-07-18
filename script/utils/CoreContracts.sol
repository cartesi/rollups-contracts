// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.30;

import {VmSafe} from "forge-std-1.9.6/src/Vm.sol";

import {AuthorityFactory} from "src/consensus/authority/AuthorityFactory.sol";
import {QuorumFactory} from "src/consensus/quorum/QuorumFactory.sol";
import {ApplicationFactory} from "src/dapp/ApplicationFactory.sol";
import {SelfHostedApplicationFactory} from "src/dapp/SelfHostedApplicationFactory.sol";
import {SafeErc20Transfer} from "src/delegatecall/SafeErc20Transfer.sol";
import {InputBox} from "src/inputs/InputBox.sol";
import {Erc1155BatchPortal} from "src/portals/Erc1155BatchPortal.sol";
import {Erc1155SinglePortal} from "src/portals/Erc1155SinglePortal.sol";
import {Erc20Portal} from "src/portals/Erc20Portal.sol";
import {Erc721Portal} from "src/portals/Erc721Portal.sol";
import {EtherPortal} from "src/portals/EtherPortal.sol";
import {RefundOutputBuilder} from "src/refund/RefundOutputBuilder.sol";
import {UsdWithdrawalOutputBuilderFactory} from "src/withdrawal/UsdWithdrawalOutputBuilderFactory.sol";

import "./ContractDeployers.sol" as G;
import {storeDeployment} from "./DeploymentStorage.sol";

struct Suite {
    ApplicationFactory applicationFactory;
    AuthorityFactory authorityFactory;
    Erc1155BatchPortal erc1155BatchPortal;
    Erc1155SinglePortal erc1155SinglePortal;
    Erc20Portal erc20Portal;
    Erc721Portal erc721Portal;
    EtherPortal etherPortal;
    InputBox inputBox;
    QuorumFactory quorumFactory;
    RefundOutputBuilder refundOutputBuilder;
    SafeErc20Transfer safeErc20Transfer;
    SelfHostedApplicationFactory selfHostedApplicationFactory;
    UsdWithdrawalOutputBuilderFactory usdWithdrawalOutputBuilderFactory;
}

function deploy() returns (Suite memory) {
    InputBox inputBox = G.deployInputBox();
    EtherPortal etherPortal = G.deployEtherPortal();
    Erc20Portal erc20Portal = G.deployErc20Portal();
    Erc721Portal erc721Portal = G.deployErc721Portal();
    Erc1155SinglePortal erc1155SinglePortal = G.deployErc1155SinglePortal();
    Erc1155BatchPortal erc1155BatchPortal = G.deployErc1155BatchPortal();
    SafeErc20Transfer safeErc20Transfer = G.deploySafeErc20Transfer();
    AuthorityFactory authorityFactory = G.deployAuthorityFactory();
    RefundOutputBuilder refundOutputBuilder = G.deployRefundOutputBuilder(
        etherPortal,
        erc20Portal,
        erc721Portal,
        erc1155SinglePortal,
        erc1155BatchPortal,
        safeErc20Transfer
    );
    ApplicationFactory applicationFactory =
        G.deployApplicationFactory(refundOutputBuilder);
    QuorumFactory quorumFactory = G.deployQuorumFactory();
    UsdWithdrawalOutputBuilderFactory usdWithdrawalOutputBuilderFactory =
        G.deployUsdWithdrawalOutputBuilderFactory(safeErc20Transfer);
    SelfHostedApplicationFactory selfHostedApplicationFactory =
        G.deploySelfHostedApplicationFactory(authorityFactory, applicationFactory);

    return Suite({
        applicationFactory: applicationFactory,
        authorityFactory: authorityFactory,
        erc1155BatchPortal: erc1155BatchPortal,
        erc1155SinglePortal: erc1155SinglePortal,
        erc20Portal: erc20Portal,
        erc721Portal: erc721Portal,
        etherPortal: etherPortal,
        inputBox: inputBox,
        quorumFactory: quorumFactory,
        refundOutputBuilder: refundOutputBuilder,
        safeErc20Transfer: safeErc20Transfer,
        selfHostedApplicationFactory: selfHostedApplicationFactory,
        usdWithdrawalOutputBuilderFactory: usdWithdrawalOutputBuilderFactory
    });
}

function store(VmSafe vmSafe, Suite memory s) {
    storeDeployment(vmSafe, type(InputBox).name, address(s.inputBox));
    storeDeployment(vmSafe, type(ApplicationFactory).name, address(s.applicationFactory));
    storeDeployment(vmSafe, type(AuthorityFactory).name, address(s.authorityFactory));
    storeDeployment(vmSafe, type(Erc1155BatchPortal).name, address(s.erc1155BatchPortal));
    storeDeployment(
        vmSafe, type(Erc1155SinglePortal).name, address(s.erc1155SinglePortal)
    );
    storeDeployment(vmSafe, type(Erc20Portal).name, address(s.erc20Portal));
    storeDeployment(vmSafe, type(Erc721Portal).name, address(s.erc721Portal));
    storeDeployment(vmSafe, type(EtherPortal).name, address(s.etherPortal));
    storeDeployment(vmSafe, type(QuorumFactory).name, address(s.quorumFactory));
    storeDeployment(vmSafe, type(SafeErc20Transfer).name, address(s.safeErc20Transfer));
    storeDeployment(
        vmSafe, type(RefundOutputBuilder).name, address(s.refundOutputBuilder)
    );
    storeDeployment(
        vmSafe,
        type(SelfHostedApplicationFactory).name,
        address(s.selfHostedApplicationFactory)
    );
    storeDeployment(
        vmSafe,
        type(UsdWithdrawalOutputBuilderFactory).name,
        address(s.usdWithdrawalOutputBuilderFactory)
    );
}
