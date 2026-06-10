// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.8;

import {Script} from "forge-std-1.9.6/src/Script.sol";

import "./utils/CoreContracts.sol" as CoreContracts;
import "./utils/DevContracts.sol" as DevContracts;

contract DeploymentScript is Script {
    uint64 constant ANVIL_CHAIN_ID = 31337;

    function run() external {
        vmSafe.startBroadcast();
        CoreContracts.Suite memory core = CoreContracts.deploy();
        vmSafe.stopBroadcast();
        CoreContracts.store(vmSafe, core);

        if (block.chainid == ANVIL_CHAIN_ID) {
            vmSafe.startBroadcast();
            DevContracts.Suite memory dev = DevContracts.deploy(core);
            vmSafe.stopBroadcast();
            DevContracts.store(vmSafe, dev);
        }
    }
}
