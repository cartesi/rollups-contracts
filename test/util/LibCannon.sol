pragma solidity ^0.8.0;

import {Vm} from "forge-std-1.9.6/src/Vm.sol";

library LibCannon {
    function getAddress(Vm vm, string memory name) internal view returns (address) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/test/", name, ".json");
        bytes memory addr = vm.parseJson(vm.readFile(path), ".address");
        return abi.decode(addr, (address));
    }
}
