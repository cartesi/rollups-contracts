// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.8;

import "forge-std-1.9.6/src/Script.sol";

import "../src/inputs/InputBox.sol";
import "../src/portals/EtherPortal.sol";
import "../src/portals/ERC20Portal.sol";
import "../src/portals/ERC721Portal.sol";
import "../src/portals/ERC1155SinglePortal.sol";
import "../src/portals/ERC1155BatchPortal.sol";
import "../src/consensus/authority/AuthorityFactory.sol";
import "../src/consensus/quorum/QuorumFactory.sol";
import "../src/dapp/ApplicationFactory.sol";
import "../src/dapp/SelfHostedApplicationFactory.sol";
import "../src/delegatecall/SafeERC20Transfer.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();

        bytes32 zeroSalt = bytes32(0);

        // === InputBox ===
        IInputBox inputBox = new InputBox{salt: zeroSalt}();

        // === Portals ===
        IEtherPortal etherPortal = new EtherPortal{salt: zeroSalt}(inputBox);
        IERC20Portal erc20Portal = new ERC20Portal{salt: zeroSalt}(inputBox);
        IERC721Portal erc721Portal = new ERC721Portal{salt: zeroSalt}(inputBox);
        IERC1155SinglePortal erc1155SinglePortal =
            new ERC1155SinglePortal{salt: zeroSalt}(inputBox);
        IERC1155BatchPortal erc1155BatchPortal =
            new ERC1155BatchPortal{salt: zeroSalt}(inputBox);

        // === Factories ===
        IAuthorityFactory authorityFactory = new AuthorityFactory{salt: zeroSalt}();
        IQuorumFactory quorumFactory = new QuorumFactory{salt: zeroSalt}();
        IApplicationFactory applicationFactory = new ApplicationFactory{salt: zeroSalt}();
        ISelfHostedApplicationFactory selfHostedApplicationFactory =
            new SelfHostedApplicationFactory{salt: zeroSalt}(
                authorityFactory,
                applicationFactory
            );

        // === Delegatecall ===
        SafeERC20Transfer safeERC20Transfer = new SafeERC20Transfer{salt: zeroSalt}();

        vm.stopBroadcast();

        console2.log("InputBox: %s", address(inputBox));
        console2.log("EtherPortal: %s", address(etherPortal));
        console2.log("ERC20Portal: %s", address(erc20Portal));
        console2.log("ERC721Portal: %s", address(erc721Portal));
        console2.log("ERC1155SinglePortal: %s", address(erc1155SinglePortal));
        console2.log("ERC1155BatchPortal: %s", address(erc1155BatchPortal));
        console2.log("AuthorityFactory: %s", address(authorityFactory));
        console2.log("QuorumFactory: %s", address(quorumFactory));
        console2.log("ApplicationFactory: %s", address(applicationFactory));
        console2.log("SelfHostedApplicationFactory: %s", address(selfHostedApplicationFactory));
        console2.log("SafeERC20Transfer: %s", address(safeERC20Transfer));

        string memory json;
        json = vm.serializeAddress("contracts", "InputBox", address(inputBox));
        json = vm.serializeAddress("contracts", "EtherPortal", address(etherPortal));
        json = vm.serializeAddress("contracts", "ERC20Portal", address(erc20Portal));
        json = vm.serializeAddress("contracts", "ERC721Portal", address(erc721Portal));
        json = vm.serializeAddress("contracts", "ERC1155SinglePortal", address(erc1155SinglePortal));
        json = vm.serializeAddress("contracts", "ERC1155BatchPortal", address(erc1155BatchPortal));
        json = vm.serializeAddress("contracts", "AuthorityFactory", address(authorityFactory));
        json = vm.serializeAddress("contracts", "QuorumFactory", address(quorumFactory));
        json = vm.serializeAddress("contracts", "ApplicationFactory", address(applicationFactory));
        json = vm.serializeAddress("contracts", "SelfHostedApplicationFactory", address(selfHostedApplicationFactory));
        json = vm.serializeAddress("contracts", "SafeERC20Transfer", address(safeERC20Transfer));
        vm.writeJson(json, "deployments.json");
    }
}
