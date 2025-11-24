// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.8;

import {BaseDeploymentScript} from "./BaseDeploymentScript.sol";

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

contract DeploymentScript is BaseDeploymentScript {
    function run() external {
        vmSafe.startBroadcast();

        address inputBox = _storeDeployment(
            type(InputBox).name, _create2(type(InputBox).creationCode, abi.encode())
        );

        _storeDeployment(
            type(EtherPortal).name,
            _create2(type(EtherPortal).creationCode, abi.encode(inputBox))
        );

        _storeDeployment(
            type(ERC20Portal).name,
            _create2(type(ERC20Portal).creationCode, abi.encode(inputBox))
        );

        _storeDeployment(
            type(ERC721Portal).name,
            _create2(type(ERC721Portal).creationCode, abi.encode(inputBox))
        );

        _storeDeployment(
            type(ERC1155SinglePortal).name,
            _create2(type(ERC1155SinglePortal).creationCode, abi.encode(inputBox))
        );

        _storeDeployment(
            type(ERC1155BatchPortal).name,
            _create2(type(ERC1155BatchPortal).creationCode, abi.encode(inputBox))
        );

        _storeDeployment(
            type(SafeERC20Transfer).name,
            _create2(type(SafeERC20Transfer).creationCode, abi.encode())
        );

        address appFactory = _storeDeployment(
            type(ApplicationFactory).name,
            _create2(type(ApplicationFactory).creationCode, abi.encode())
        );

        address authorityFactory = _storeDeployment(
            type(AuthorityFactory).name,
            _create2(type(AuthorityFactory).creationCode, abi.encode())
        );

        _storeDeployment(
            type(QuorumFactory).name,
            _create2(type(QuorumFactory).creationCode, abi.encode())
        );

        _storeDeployment(
            type(SelfHostedApplicationFactory).name,
            _create2(
                type(SelfHostedApplicationFactory).creationCode,
                abi.encode(authorityFactory, appFactory)
            )
        );

        vmSafe.stopBroadcast();
    }
}
