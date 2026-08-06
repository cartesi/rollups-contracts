// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.30;

import {Script} from "forge-std-1.9.6/src/Script.sol";
import {VmSafe} from "forge-std-1.9.6/src/Vm.sol";

contract DeploymentSummaryScript is Script {
    function run() external {
        string memory summary = _buildSummary();
        vmSafe.createDir("deployments", true);
        // forge-lint: disable-next-line(unsafe-cheatcode)
        vmSafe.writeFile(string.concat("deployments/summary.txt"), summary);
    }

    function _buildSummary() internal view returns (string memory summary) {
        VmSafe.DirEntry[] memory dirEntries = vmSafe.readDir("deployments", 2, false);
        for (uint256 i; i < dirEntries.length; ++i) {
            VmSafe.DirEntry memory dirEntry = dirEntries[i];
            if (dirEntry.depth == 2 && _isJsonFilePath(dirEntry.path)) {
                // forge-lint: disable-next-line(unsafe-cheatcode)
                string memory json = vmSafe.readFile(dirEntry.path);
                string memory contractName = vmSafe.parseJsonString(json, ".contractName");
                address addr = vmSafe.parseJsonAddress(json, ".address");
                string memory dirBaseName = _getFileDirBaseName(dirEntry.path);
                uint256 chainId = vmSafe.parseUint(dirBaseName);
                string memory summaryLine = _buildSummaryLine(chainId, contractName, addr);
                summary = string.concat(summary, summaryLine, "\n");
            }
        }
    }

    /// @notice Construct a summary line (without \n) from its constituent parts.
    function _buildSummaryLine(uint256 chainId, string memory contractName, address addr)
        internal
        pure
        returns (string memory)
    {
        string memory chainIdStr = vmSafe.toString(chainId);
        string memory addrStr = vmSafe.toString(addr);
        return string.concat(chainIdStr, " ", contractName, " ", addrStr);
    }

    /// @notice Check whether a file path points to a JSON file.
    /// @dev Checks (1) whether it is a file and (2) whether its path ends in `.json`.
    function _isJsonFilePath(string memory path) internal view returns (bool) {
        if (!vmSafe.isFile(path)) return false;
        string[] memory parts = vmSafe.split(path, ".");
        if (parts.length == 0) return false;
        string memory ext = parts[parts.length - 1];
        return keccak256(bytes(ext)) == keccak256("json");
    }

    /// @notice Get the directory base name of a file. Fails for root files.
    /// @dev For example, ./deployments/11155111/InputBox.json --> 11155111
    function _getFileDirBaseName(string memory path)
        internal
        pure
        returns (string memory)
    {
        string[] memory parts = vmSafe.split(path, "/");
        return parts[parts.length - 2];
    }
}
