// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.8;

import {BaseDeploymentScript} from "./BaseDeploymentScript.sol";

import {AuthorityFactory} from "src/consensus/authority/AuthorityFactory.sol";
import {QuorumFactory} from "src/consensus/quorum/QuorumFactory.sol";
import {ApplicationFactory} from "src/dapp/ApplicationFactory.sol";
import {SelfHostedApplicationFactory} from "src/dapp/SelfHostedApplicationFactory.sol";
import {SafeERC20Transfer} from "src/delegatecall/SafeERC20Transfer.sol";
import {TestFungibleToken} from "src/devnet/TestFungibleToken.sol";
import {TestMultiToken} from "src/devnet/TestMultiToken.sol";
import {TestNonFungibleToken} from "src/devnet/TestNonFungibleToken.sol";
import {InputBox} from "src/inputs/InputBox.sol";
import {ERC1155BatchPortal} from "src/portals/ERC1155BatchPortal.sol";
import {ERC1155SinglePortal} from "src/portals/ERC1155SinglePortal.sol";
import {ERC20Portal} from "src/portals/ERC20Portal.sol";
import {ERC721Portal} from "src/portals/ERC721Portal.sol";
import {EtherPortal} from "src/portals/EtherPortal.sol";
import {UsdWithdrawalOutputBuilder} from "src/withdrawal/UsdWithdrawalOutputBuilder.sol";

contract DeploymentScript is BaseDeploymentScript {
    // Chain IDs
    // See <https://chainlist.org>
    uint64 constant ANVIL_CHAIN_ID = 31337;
    uint64 constant ARBITRUM_MAINNET_CHAIN_ID = 42161;
    uint64 constant ARBITRUM_SEPOLIA_CHAIN_ID = 421614;
    uint64 constant BASE_MAINNET_CHAIN_ID = 8453;
    uint64 constant BASE_SEPOLIA_CHAIN_ID = 84532;
    uint64 constant ETHEREUM_MAINNET_CHAIN_ID = 1;
    uint64 constant ETHEREUM_SEPOLIA_CHAIN_ID = 11155111;
    uint64 constant OP_MAINNET_CHAIN_ID = 10;
    uint64 constant OP_SEPOLIA_CHAIN_ID = 11155420;

    // USDC token contract addresses
    // See <https://developers.circle.com/stablecoins/usdc-contract-addresses>
    address constant ARBITRUM_MAINNET_USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address constant ARBITRUM_SEPOLIA_USDC = 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d;
    address constant BASE_MAINNET_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant BASE_SEPOLIA_USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    address constant ETHEREUM_MAINNET_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant ETHEREUM_SEPOLIA_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    address constant OP_MAINNET_USDC = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
    address constant OP_SEPOLIA_USDC = 0x5fd84259d66Cd46123540766Be93DFE6D43130D7;

    // USDC token contract addresses indexed by chain ID
    mapping(uint256 => address) _usdc;

    function run() external {
        _usdc[ARBITRUM_MAINNET_CHAIN_ID] = ARBITRUM_MAINNET_USDC;
        _usdc[ARBITRUM_SEPOLIA_CHAIN_ID] = ARBITRUM_SEPOLIA_USDC;
        _usdc[BASE_MAINNET_CHAIN_ID] = BASE_MAINNET_USDC;
        _usdc[BASE_SEPOLIA_CHAIN_ID] = BASE_SEPOLIA_USDC;
        _usdc[ETHEREUM_MAINNET_CHAIN_ID] = ETHEREUM_MAINNET_USDC;
        _usdc[ETHEREUM_SEPOLIA_CHAIN_ID] = ETHEREUM_SEPOLIA_USDC;
        _usdc[OP_MAINNET_CHAIN_ID] = OP_MAINNET_USDC;
        _usdc[OP_SEPOLIA_CHAIN_ID] = OP_SEPOLIA_USDC;

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

        address safeErc20Transfer = _storeDeployment(
            type(SafeERC20Transfer).name,
            _create2(type(SafeERC20Transfer).creationCode, abi.encode())
        );

        address erc20Token;

        if (block.chainid == ANVIL_CHAIN_ID) {
            erc20Token = _storeDeployment(
                type(TestFungibleToken).name,
                _create2(type(TestFungibleToken).creationCode, abi.encode())
            );
            _storeDeployment(
                type(TestNonFungibleToken).name,
                _create2(type(TestNonFungibleToken).creationCode, abi.encode())
            );
            _storeDeployment(
                type(TestMultiToken).name,
                _create2(type(TestMultiToken).creationCode, abi.encode())
            );
        } else {
            erc20Token = _usdc[block.chainid];
        }

        if (erc20Token != address(0)) {
            require(
                erc20Token.code.length > 0,
                "Expected ERC-20 token contract address to have code"
            );
            _storeDeployment(
                type(UsdWithdrawalOutputBuilder).name,
                _create2(
                    type(UsdWithdrawalOutputBuilder).creationCode,
                    abi.encode(safeErc20Transfer, erc20Token)
                )
            );
        }

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
