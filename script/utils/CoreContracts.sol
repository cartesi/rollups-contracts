// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.8;

import {VmSafe} from "forge-std-1.9.6/src/Vm.sol";

import {AuthorityFactory} from "src/consensus/authority/AuthorityFactory.sol";
import {QuorumFactory} from "src/consensus/quorum/QuorumFactory.sol";
import {ApplicationFactory} from "src/dapp/ApplicationFactory.sol";
import {SelfHostedApplicationFactory} from "src/dapp/SelfHostedApplicationFactory.sol";
import {SafeERC20Transfer} from "src/delegatecall/SafeERC20Transfer.sol";
import {InputBox} from "src/inputs/InputBox.sol";
import {ERC1155BatchPortal} from "src/portals/ERC1155BatchPortal.sol";
import {ERC1155SinglePortal} from "src/portals/ERC1155SinglePortal.sol";
import {ERC20Portal} from "src/portals/ERC20Portal.sol";
import {ERC721Portal} from "src/portals/ERC721Portal.sol";
import {EtherPortal} from "src/portals/EtherPortal.sol";
import {
    UsdWithdrawalOutputBuilderFactory
} from "src/withdrawal/UsdWithdrawalOutputBuilderFactory.sol";

import "./ContractDeployers.sol" as G;
import {storeDeployment} from "./DeploymentStorage.sol";

struct Suite {
    ApplicationFactory applicationFactory;
    AuthorityFactory authorityFactory;
    ERC1155BatchPortal erc1155BatchPortal;
    ERC1155SinglePortal erc1155SinglePortal;
    ERC20Portal erc20Portal;
    ERC721Portal erc721Portal;
    EtherPortal etherPortal;
    InputBox inputBox;
    QuorumFactory quorumFactory;
    SafeERC20Transfer safeErc20Transfer;
    SelfHostedApplicationFactory selfHostedApplicationFactory;
    UsdWithdrawalOutputBuilderFactory usdWithdrawalOutputBuilderFactory;
}

function deploy() returns (Suite memory) {
    InputBox inputBox = G.deployInputBox();
    EtherPortal etherPortal = G.deployEtherPortal(inputBox);
    ERC20Portal erc20Portal = G.deployERC20Portal(inputBox);
    ERC721Portal erc721Portal = G.deployERC721Portal(inputBox);
    ERC1155SinglePortal erc1155SinglePortal = G.deployERC1155SinglePortal(inputBox);
    ERC1155BatchPortal erc1155BatchPortal = G.deployERC1155BatchPortal(inputBox);
    SafeERC20Transfer safeErc20Transfer = G.deploySafeERC20Transfer();
    AuthorityFactory authorityFactory = G.deployAuthorityFactory();
    ApplicationFactory applicationFactory = G.deployApplicationFactory();
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
        safeErc20Transfer: safeErc20Transfer,
        selfHostedApplicationFactory: selfHostedApplicationFactory,
        usdWithdrawalOutputBuilderFactory: usdWithdrawalOutputBuilderFactory
    });
}

function store(VmSafe vmSafe, Suite memory s) {
    storeDeployment(vmSafe, type(InputBox).name, address(s.inputBox));
    storeDeployment(vmSafe, type(ApplicationFactory).name, address(s.applicationFactory));
    storeDeployment(vmSafe, type(AuthorityFactory).name, address(s.authorityFactory));
    storeDeployment(vmSafe, type(ERC1155BatchPortal).name, address(s.erc1155BatchPortal));
    storeDeployment(
        vmSafe, type(ERC1155SinglePortal).name, address(s.erc1155SinglePortal)
    );
    storeDeployment(vmSafe, type(ERC20Portal).name, address(s.erc20Portal));
    storeDeployment(vmSafe, type(ERC721Portal).name, address(s.erc721Portal));
    storeDeployment(vmSafe, type(EtherPortal).name, address(s.etherPortal));
    storeDeployment(vmSafe, type(QuorumFactory).name, address(s.quorumFactory));
    storeDeployment(vmSafe, type(SafeERC20Transfer).name, address(s.safeErc20Transfer));
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
