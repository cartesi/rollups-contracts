// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.30;

import {VmSafe} from "forge-std-1.9.6/src/Vm.sol";

/// @notice Store a deployment in both TXT and JSON formats.
/// @param vmSafe The safe Forge VM interface
/// @param contractName The contract name
/// @param deployment The deployment address
function storeDeployment(VmSafe vmSafe, string memory contractName, address deployment) {
    string memory deploymentStr = vmSafe.toString(deployment);
    string memory objectKey = string.concat(contractName, "@", deploymentStr);
    string memory json;
    json = vmSafe.serializeAddress(objectKey, "address", deployment);
    json = vmSafe.serializeString(objectKey, "contractName", contractName);
    string memory dir = string.concat("deployments/", vmSafe.toString(block.chainid));
    vmSafe.createDir(dir, true);
    vmSafe.writeFile(string.concat(dir, "/", contractName, ".txt"), deploymentStr);
    vmSafe.writeFile(string.concat(dir, "/", contractName, ".json"), json);
}
