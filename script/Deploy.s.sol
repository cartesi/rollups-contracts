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
    /// @notice Deploy the Cartesi Rollups contracts.
    /// @dev Serializes deployed contract addresses to `deployments.json`.
    function run() external {
        vm.startBroadcast();
        _deployContracts();
        vm.stopBroadcast();
        vm.writeJson(_serializeDeployments(), "deployments.json");
    }

    /// @notice Deploy contracts deterministically.
    /// @dev The zero hash is used as salt for all deployments.
    function _deployContracts() internal {
        bytes32 salt;
        InputBox inputBox = new InputBox{salt: salt}();
        new EtherPortal{salt: salt}(inputBox);
        new ERC20Portal{salt: salt}(inputBox);
        new ERC721Portal{salt: salt}(inputBox);
        new ERC1155SinglePortal{salt: salt}(inputBox);
        new ERC1155BatchPortal{salt: salt}(inputBox);
        new SafeERC20Transfer{salt: salt}();
        ApplicationFactory appFactory = new ApplicationFactory{salt: salt}();
        AuthorityFactory authorityFactory = new AuthorityFactory{salt: salt}();
        new QuorumFactory{salt: salt}();
        new SelfHostedApplicationFactory{salt: salt}(authorityFactory, appFactory);
    }

    /// @notice Serialize the deployments in a JSON object
    /// @return The deployments JSON object
    function _serializeDeployments() internal returns (string memory) {
        string memory json;
        json = _serializeDeployment("InputBox");
        json = _serializeDeployment("EtherPortal");
        json = _serializeDeployment("ERC20Portal");
        json = _serializeDeployment("ERC721Portal");
        json = _serializeDeployment("ERC1155SinglePortal");
        json = _serializeDeployment("ERC1155BatchPortal");
        json = _serializeDeployment("AuthorityFactory");
        json = _serializeDeployment("QuorumFactory");
        json = _serializeDeployment("ApplicationFactory");
        json = _serializeDeployment("SafeERC20Transfer");
        json = _serializeDeployment("SelfHostedApplicationFactory");
        return json;
    }

    /// @notice Serialize a deployment in the deployments JSON object.
    /// @param contractName The contract name
    /// @return The updated deployments JSON object
    function _serializeDeployment(string memory contractName)
        internal
        returns (string memory)
    {
        address deployment = vm.getDeployment(contractName);
        return vm.serializeAddress("deployments", contractName, deployment);
    }
}
