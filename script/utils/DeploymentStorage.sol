// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.8;

import {VmSafe} from "forge-std-1.9.6/src/Vm.sol";

/// @notice Store a deployment in a JSON file.
/// @param vmSafe The safe Forge VM interface
/// @param contractName The contract name
/// @param deployment The deployment address
/// @return deployment The deployment address
function storeDeployment(VmSafe vmSafe, string memory contractName, address deployment)
    returns (address)
{
    string memory deploymentStr = vmSafe.toString(deployment);
    string memory objectKey = string.concat(contractName, "@", deploymentStr);
    string memory json;
    json = vmSafe.serializeAddress(objectKey, "address", deployment);
    json = vmSafe.serializeString(objectKey, "contractName", contractName);
    string memory dir = getCurrentChainDeploymentsDir(vmSafe, ".");
    vmSafe.createDir(dir, true);
    string memory path = getDeploymentFilePath(dir, contractName);
    vmSafe.writeJson(json, path);
    return deployment;
}

/// @notice Load a deployment from a JSON file.
/// @param vmSafe The safe Forge VM interface
/// @param projectRoot The project root path
/// @param contractName The contract name
/// @return deployment The deployment address
function loadDeployment(
    VmSafe vmSafe,
    string memory projectRoot,
    string memory contractName
) view returns (address deployment) {
    string memory dir = getCurrentChainDeploymentsDir(vmSafe, projectRoot);
    string memory path = getDeploymentFilePath(dir, contractName);
    /// forge-lint: disable-next-line(unsafe-cheatcode)
    string memory json = vmSafe.readFile(path);
    return vmSafe.parseJsonAddress(json, ".address");
}

/// @notice Get the deployment directory of a project given the current chain.
/// @param vmSafe The safe Forge VM interface
/// @param projectRoot The project root path
/// @return dir The project's deployments directory for the current chain
function getCurrentChainDeploymentsDir(VmSafe vmSafe, string memory projectRoot)
    view
    returns (string memory dir)
{
    dir = string.concat(projectRoot, "/deployments/", vmSafe.toString(block.chainid));
}

/// @notice Get the path of a deployment file given the directory and contract name.
/// @param dir The deployment directory (see `getCurrentChainDeploymentsDir`)
/// @param contractName The contract name
/// @return path The deployment file path
function getDeploymentFilePath(string memory dir, string memory contractName)
    pure
    returns (string memory path)
{
    path = string.concat(dir, "/", contractName, ".json");
}
