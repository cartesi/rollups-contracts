// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.8;

import {Script} from "forge-std-1.9.6/src/Script.sol";

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

contract DeployScript is Script {
    /// @notice Salt used on deterministic deployments.
    bytes32 constant SALT = bytes32(0);

    /// @notice Deploy the Cartesi Rollups contracts.
    /// @dev Serializes deployed contract addresses to `deployments.json`.
    function run() external {
        vm.startBroadcast();
        InputBox inputBox = new InputBox{salt: SALT}();
        EtherPortal etherPortal = new EtherPortal{salt: SALT}(inputBox);
        ERC20Portal erc20Portal = new ERC20Portal{salt: SALT}(inputBox);
        ERC721Portal erc721Portal = new ERC721Portal{salt: SALT}(inputBox);
        ERC1155SinglePortal erc1155SinglePortal =
            new ERC1155SinglePortal{salt: SALT}(inputBox);
        ERC1155BatchPortal erc1155BatchPortal =
            new ERC1155BatchPortal{salt: SALT}(inputBox);
        SafeERC20Transfer safeErc20Transfer = new SafeERC20Transfer{salt: SALT}();
        ApplicationFactory appFactory = new ApplicationFactory{salt: SALT}();
        AuthorityFactory authorityFactory = new AuthorityFactory{salt: SALT}();
        QuorumFactory quorumFactory = new QuorumFactory{salt: SALT}();
        SelfHostedApplicationFactory selfHostedAppFactory =
            new SelfHostedApplicationFactory{salt: SALT}(authorityFactory, appFactory);
        vm.stopBroadcast();

        string memory json;
        json = _add("InputBox", address(inputBox));
        json = _add("EtherPortal", address(etherPortal));
        json = _add("ERC20Portal", address(erc20Portal));
        json = _add("ERC721Portal", address(erc721Portal));
        json = _add("ERC1155SinglePortal", address(erc1155SinglePortal));
        json = _add("ERC1155BatchPortal", address(erc1155BatchPortal));
        json = _add("AuthorityFactory", address(authorityFactory));
        json = _add("QuorumFactory", address(quorumFactory));
        json = _add("ApplicationFactory", address(appFactory));
        json = _add("SafeERC20Transfer", address(safeErc20Transfer));
        json = _add("SelfHostedApplicationFactory", address(selfHostedAppFactory));
        vm.writeJson(json, "deployments.json");
    }

    /// @notice Add a deployment to the deployments JSON object.
    /// @param contractName The contract name
    /// @param deployment The deployment address
    /// @return The deployments JSON object after the addition.
    function _add(string memory contractName, address deployment)
        internal
        returns (string memory)
    {
        return vm.serializeAddress("deployments", contractName, deployment);
    }
}
