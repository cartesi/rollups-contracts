// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

pragma solidity ^0.8.22;

interface IEtherReceiver {
    function balanceOf(address who) external view returns (uint256);
    function mint() external payable;
}

contract EtherReceiver is IEtherReceiver {
    mapping(address => uint256) public balanceOf;

    function mint() external payable override {
        balanceOf[msg.sender] += msg.value;
    }
}
