// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

import {Test} from "forge-std-1.9.6/src/Test.sol";

contract AddressGenerator is Test {
    uint256 private _addressCount;

    function _nextAddress() internal returns (address) {
        bytes memory seed = abi.encode(type(AddressGenerator).name, ++_addressCount);
        return vm.addr(boundPrivateKey(uint256(keccak256(seed))));
    }
}
