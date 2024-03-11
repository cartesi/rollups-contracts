// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

contract EtherReceiver {
    mapping(address => uint256) public balanceOf;

    function mint() external payable {
        balanceOf[msg.sender] += msg.value;
    }
}
